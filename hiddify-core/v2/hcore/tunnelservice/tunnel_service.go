package tunnelservice

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/option"

	hcommon "github.com/hiddify/hiddify-core/v2/hcommon"
	"github.com/hiddify/hiddify-core/v2/hcore"
)

type TunnelService struct {
	UnimplementedTunnelServiceServer

	// mu guards box and hostsGen. hostsGen invalidates in-flight async
	// hosts-override writes: Start bumps it and hands the value to the
	// resolver goroutine; Stop/Exit bump it again so a write that finishes
	// after teardown becomes a no-op instead of leaving a stale block in
	// /etc/hosts.
	mu       sync.Mutex
	box      *libbox.BoxService
	hostsGen uint64
}

// tunnelWorkDir is writable by the root LaunchDaemon. macOS system volume (/)
// is read-only, so relative paths like "cache.db" fail with EROFS.
func tunnelWorkDir() string {
	return "/Library/Application Support/HiddifyTunnelService"
}

func ensureTunnelWorkDir() (string, error) {
	dir := tunnelWorkDir()
	if err := os.MkdirAll(filepath.Join(dir, "data"), 0o755); err != nil {
		dir = filepath.Join(os.TempDir(), "HiddifyTunnelService")
		if err2 := os.MkdirAll(filepath.Join(dir, "data"), 0o755); err2 != nil {
			return "", fmt.Errorf("create tunnel work dir: %w (also: %v)", err2, err)
		}
	}
	if err := os.Chdir(dir); err != nil {
		return "", fmt.Errorf("chdir tunnel work dir: %w", err)
	}
	return dir, nil
}

func (s *TunnelService) Start(ctx context.Context, in *TunnelStartRequest) (*TunnelResponse, error) {
	if in.ServerPort == 0 {
		in.ServerPort = 12334
	}
	workDir, err := ensureTunnelWorkDir()
	if err != nil {
		return &TunnelResponse{Message: err.Error()}, err
	}
	opt := makeTunnelConfig(in, workDir)

	instance, err := hcore.NewService(opt)
	if err != nil {
		return &TunnelResponse{
			Message: err.Error(),
		}, err
	}
	err = instance.Start()
	if err != nil {
		_ = instance.Close()
		return &TunnelResponse{
			Message: err.Error(),
		}, err
	}
	s.mu.Lock()
	old := s.box
	s.box = instance
	firstStart := old == nil
	var gen uint64
	if firstStart {
		s.hostsGen++
		gen = s.hostsGen
	}
	s.mu.Unlock()
	if old != nil {
		// Replace the running box (office-media toggle) without touching
		// /etc/hosts or mDNSResponder — those blips drop Electron apps.
		_ = old.Close()
	} else {
		go s.applyHostsOverrideAsync(gen)
	}

	return &TunnelResponse{
		Message: "OK",
	}, nil
}

// applyHostsOverrideAsync resolves and installs the poison-override hosts
// block. Resolution is slow (serial dig with per-query timeouts), so a quick
// connect->disconnect used to lose a race: Stop cleaned /etc/hosts before
// this goroutine wrote the block. The generation check makes any write that
// lands after Stop/Exit (or a newer Start) a no-op.
func (s *TunnelService) applyHostsOverrideAsync(gen uint64) {
	// Do not restoreDNSOverride here: Start used to HUP mDNSResponder
	// (and sometimes wipe DNS) on every connect, which leaves Electron
	// apps (Bilibili) unable to resume until they are restarted. Cleanup
	// belongs on Stop. writePoisonHostsBlock replaces any leftover block.
	body, ok := resolvePoisonHostsBlock()
	if !ok {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.hostsGen != gen || s.box == nil {
		return
	}
	_ = writePoisonHostsBlock(body)
}

func makeTunnelConfig(in *TunnelStartRequest, workDir string) option.Options {
	ips := []netip.Prefix{netip.MustParsePrefix("172.20.0.1/30")}
	if in.Ipv6 {
		ips = append(ips, netip.MustParsePrefix("fdfe:dcba:9876::1/126"))
	}
	parsed := parseTunnelStack(in.Stack)
	routeExclude := []netip.Prefix{
		netip.MustParsePrefix("10.0.0.0/8"),
		netip.MustParsePrefix("172.16.0.0/12"),
		netip.MustParsePrefix("192.168.0.0/16"),
		netip.MustParsePrefix("127.0.0.0/8"),
		netip.MustParsePrefix("169.254.0.0/16"),
		netip.MustParsePrefix("3.3.0.0/16"),
	}
	routeExclude = append(routeExclude, parsed.extraExclude...)
	// EasyConnect portal hosts must never enter TUN: after DNS, the client
	// dials bare IPs, so domain rules alone are not enough. Exclude resolved
	// A records from AutoRoute so login works even when LisaSpeed is already up.
	for _, host := range []string{"vpn.moutai.com.cn", "moutai.com.cn"} {
		routeExclude = append(routeExclude, resolveHostPrefixes(host)...)
	}

	directCIDRs := []string{
		"10.0.0.0/8",
		"172.16.0.0/12",
		"192.168.0.0/16",
		"127.0.0.0/8",
		"169.254.0.0/16",
		"3.3.0.0/16",
		"fc00::/7",
		"fe80::/10",
	}
	for _, p := range routeExclude {
		directCIDRs = append(directCIDRs, p.String())
	}

	return option.Options{
		Log: &option.LogOptions{Level: "warn", Timestamp: true},
		Inbounds: []option.Inbound{
			{
				Type: C.TypeTun,
				Tag:  "tun-in",
				TunOptions: option.TunInboundOptions{
					EndpointIndependentNat: in.EndpointIndependentNat,
					StrictRoute:            in.StrictRoute,
					AutoRoute:              true,
					Address:                ips,
					RouteExcludeAddress:    routeExclude,
					InterfaceName:          "",
					Stack:                  parsed.stack,
					InboundOptions: option.InboundOptions{
						SniffEnabled:             true,
						SniffOverrideDestination: true,
					},
				},
			},
		},
		Outbounds: []option.Outbound{
			{
				Type: C.TypeSOCKS,
				Tag:  "socks-out",
				SocksOptions: option.SocksOutboundOptions{
					ServerOptions: option.ServerOptions{
						Server:     "127.0.0.1",
						ServerPort: uint16(in.ServerPort),
					},
					Username: in.ServerUsername,
					Password: in.ServerPassword,
					Version:  "5",
				},
			},
			{
				Type: C.TypeDirect,
				Tag:  "direct-out",
			},
			{
				Type: C.TypeBlock,
				Tag:  "block-out",
			},
		},
		Route: &option.RouteOptions{
			Final:               "socks-out",
			AutoDetectInterface: true,
			// China direct: geosite-cn (domains) + geoip-cn (IPs after resolve).
			// Downloaded via socks so GitHub is reachable while TUN is up.
			RuleSet: []option.RuleSet{
				{
					Type:   C.RuleSetTypeRemote,
					Tag:    "geosite-cn",
					Format: C.RuleSetFormatBinary,
					RemoteOptions: option.RemoteRuleSet{
						URL:            "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/country/geosite-cn.srs",
						DownloadDetour: "socks-out",
						UpdateInterval: option.Duration(5 * 24 * time.Hour),
					},
				},
				{
					Type:   C.RuleSetTypeRemote,
					Tag:    "geoip-cn",
					Format: C.RuleSetFormatBinary,
					RemoteOptions: option.RemoteRuleSet{
						URL:            "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/country/geoip-cn.srs",
						DownloadDetour: "socks-out",
						UpdateInterval: option.Duration(5 * 24 * time.Hour),
					},
				},
			},
			Rules: tunnelRouteRules(directCIDRs, parsed.officeMedia, officeMediaAppsFromStack(parsed)),
		},
		Experimental: &option.ExperimentalOptions{
			CacheFile: &option.CacheFileOptions{
				Enabled: true,
				Path:    filepath.Join(workDir, "cache.db"),
			},
			// Local-only Clash API so the GUI can group live connections by
			// process path (socks-out vs direct-out) for selected Mac apps.
			ClashAPI: &option.ClashAPIOptions{
				ExternalController: tunnelClashAPIAddr,
			},
		},
	}
}

const officeMediaStackFlag = "+office-media"
const excludeStackPrefix = "+ex:"
const appStackPrefix = "+app:"
const maxOfficeMediaApps = 40
const tunnelClashAPIAddr = "127.0.0.1:16757"

const noneAppSentinel = "_none"

type parsedTunnelStack struct {
	stack         string
	officeMedia   bool
	extraExclude  []netip.Prefix
	apps          []string
	appsSpecified bool
}

func encodeOfficeMediaApps(apps []string) string {
	var b strings.Builder
	seen := map[string]bool{}
	n := 0
	for _, name := range apps {
		name = sanitizeOfficeMediaApp(name)
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		n++
		if n > maxOfficeMediaApps {
			break
		}
		b.WriteString(appStackPrefix)
		b.WriteString(url.PathEscape(name))
	}
	if b.Len() == 0 {
		return appStackPrefix + noneAppSentinel
	}
	return b.String()
}

func parseTunnelStack(raw string) parsedTunnelStack {
	var out parsedTunnelStack
	parts := strings.Split(raw, "+")
	if len(parts) == 0 || parts[0] == "" {
		out.stack = "gvisor"
	} else {
		out.stack = parts[0]
	}
	for _, part := range parts[1:] {
		switch {
		case part == "office-media":
			out.officeMedia = true
		case strings.HasPrefix(part, "ex:"):
			addr, err := netip.ParseAddr(strings.TrimPrefix(part, "ex:"))
			if err != nil || !addr.Is4() {
				continue
			}
			out.extraExclude = append(out.extraExclude, netip.PrefixFrom(addr, 32))
		case strings.HasPrefix(part, "app:"):
			out.appsSpecified = true
			rawName := strings.TrimPrefix(part, "app:")
			name, err := url.PathUnescape(rawName)
			if err != nil {
				name = rawName
			}
			if name == noneAppSentinel {
				continue
			}
			name = sanitizeOfficeMediaApp(name)
			if name == "" {
				continue
			}
			out.apps = append(out.apps, name)
		}
	}
	return out
}

// applyOfficeMediaToStack keeps the TUN stack and node-IP excludes, then
// rewrites the office-media process-routing flags. Used to hot-reload the
// helper without tearing down the GUI core.
func applyOfficeMediaToStack(raw string, enabled bool, apps []string) string {
	parsed := parseTunnelStack(raw)
	var b strings.Builder
	b.WriteString(parsed.stack)
	for _, p := range parsed.extraExclude {
		b.WriteString(excludeStackPrefix)
		b.WriteString(p.Addr().String())
	}
	if enabled {
		b.WriteString(officeMediaStackFlag)
		b.WriteString(encodeOfficeMediaApps(apps))
	}
	return b.String()
}

func officeMediaAppsFromStack(parsed parsedTunnelStack) []string {
	if !parsed.officeMedia {
		return nil
	}
	if parsed.appsSpecified {
		return parsed.apps
	}
	return nil
}

func sanitizeOfficeMediaApp(name string) string {
	name = strings.TrimSpace(name)
	name = strings.TrimSuffix(name, ".app")
	if name == "" || strings.EqualFold(name, "LisaSpeed") || strings.EqualFold(name, "Hiddify") {
		return ""
	}
	return name
}

func tunnelRouteRules(directCIDRs []string, officeMedia bool, apps []string) []option.Rule {
	rules := []option.Rule{
		{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				ProcessPathRegex: []string{`LisaSpeed\.app/`},
				Outbound:         "direct-out",
			},
		},
		{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				ProcessName: []string{
					"Hiddify.exe",
					"Hiddify",
					"HiddifyCli",
					"HiddifyCli.exe",
					"LisaSpeed",
					"EasyConnect",
					"EasyConnect Helper",
					"EasyConnect Helper (GPU)",
					"EasyConnect Helper (Plugin)",
					"EasyConnect Helper (Renderer)",
					"ECAgent",
					"ECAgentProxy",
					"EasyMonitor",
					"svpnservice",
					"CSClient",
					"RSessionClient",
					"SSLVPNCD",
					"openvpn",
					"Tunnelblick",
					"Bastion",
					"bh_am_pfe_tunnel",
					"WeChat",
					// Do NOT bypass Cursor here: its model/API traffic must
					// use socks-out. Process direct makes Cursor egress via CN
					// IP and triggers "provider not supported in your region".
				},
				Outbound: "direct-out",
			},
		},
		{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				Network:  []string{"udp"},
				Port:     []uint16{443},
				Outbound: "block-out",
			},
		},
	}
	if officeMedia {
		rules = append(rules, officeMediaProxyRules(apps)...)
	}
	return append(rules,
		option.Rule{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				IPCIDR:   directCIDRs,
				Outbound: "direct-out",
			},
		},
		option.Rule{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				RuleSet:  []string{"geosite-cn", "geoip-cn"},
				Outbound: "direct-out",
			},
		},
		option.Rule{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				DomainSuffix: []string{
					".cn",
					".中国",
					"baidu.com",
					"bdstatic.com",
					"bcebos.com",
					"iqiyi.com",
					"youku.com",
					"163.com",
					"126.com",
					"127.net",
					"netease.com",
					"zhihu.com",
					"zhimg.com",
					"weibo.com",
					"sina.com.cn",
					"sinaimg.cn",
					"sohu.com",
					"sogou.com",
					"360.cn",
					"qihoo.com",
					"cctv.com",
					"cntv.cn",
					"mi.com",
					"xiaomi.com",
					"huawei.com",
					"hicloud.com",
					"meituan.com",
					"dianping.com",
					"ele.me",
					"cainiao.com",
					"tmall.com",
					"alipay.com",
					"alipayobjects.com",
					"amap.com",
					"autonavi.com",
					"pinduoduo.com",
					"yangkeduo.com",
					"jd.com",
					"360buyimg.com",
					"taobao.com",
					"alicdn.com",
					"aliyuncs.com",
					"aliyun.com",
					"qq.com",
					"weixin.qq.com",
					"wechat.com",
					"qcloud.com",
					"tencent.com",
					"tencent-cloud.com",
					"gtimg.com",
					"idqqimg.com",
					"servicewechat.com",
					"sangfor.com",
					"sangfor.com.cn",
					"easyconnect.cn",
					"atrust.sangfor.com",
					"moutai.com.cn",
					"moutaichina.com",
					"moutai.com",
					"vpn.moutai.com.cn",
					"ipip.net",
					"cip.cc",
					"ip138.com",
					"chinaz.com",
				},
				Outbound: "direct-out",
			},
		},
	)
}

func officeMediaProxyRules(apps []string) []option.Rule {
	apps = uniqueOfficeMediaApps(apps)
	rules := make([]option.Rule, 0, 8)
	if paths := officeMediaProcessPathRegexes(apps); len(paths) > 0 {
		rules = append(rules,
			option.Rule{
				Type: C.RuleTypeDefault,
				DefaultOptions: option.DefaultRule{
					ProcessPathRegex: paths,
					Protocol:         []string{"quic"},
					Outbound:         "block-out",
				},
			},
			option.Rule{
				Type: C.RuleTypeDefault,
				DefaultOptions: option.DefaultRule{
					ProcessPathRegex: paths,
					Network:          []string{"udp"},
					Port:             []uint16{443},
					Outbound:         "block-out",
				},
			},
			option.Rule{
				Type: C.RuleTypeDefault,
				DefaultOptions: option.DefaultRule{
					ProcessPathRegex: paths,
					Outbound:         "socks-out",
				},
			},
		)
	}
	if names := officeMediaProcessNames(apps); len(names) > 0 {
		rules = append(rules, option.Rule{
			Type: C.RuleTypeDefault,
			DefaultOptions: option.DefaultRule{
				ProcessName: names,
				Outbound:    "socks-out",
			},
		})
	}
	return rules
}

func uniqueOfficeMediaApps(apps []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(apps))
	for _, name := range apps {
		name = sanitizeOfficeMediaApp(name)
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		out = append(out, name)
	}
	return out
}

func officeMediaProcessPathRegexes(apps []string) []string {
	out := make([]string, 0, len(apps))
	for _, name := range apps {
		out = append(out, regexp.QuoteMeta(name)+`\.app/`)
	}
	return out
}

func officeMediaProcessNames(apps []string) []string {
	out := make([]string, 0, len(apps)*6)
	for _, name := range apps {
		out = append(out, electronProcessNames(name)...)
	}
	return out
}

func electronProcessNames(app string) []string {
	return []string{
		app,
		app + " Helper",
		app + " Helper (GPU)",
		app + " Helper (Plugin)",
		app + " Helper (Renderer)",
		app + " Login Helper",
	}
}

func resolveHostPrefixes(host string) []netip.Prefix {
	ips, err := net.LookupIP(host)
	if err != nil {
		return nil
	}
	seen := map[netip.Addr]bool{}
	var out []netip.Prefix
	for _, ip := range ips {
		v4 := ip.To4()
		if v4 == nil {
			continue
		}
		addr, ok := netip.AddrFromSlice(v4)
		if !ok || seen[addr] {
			continue
		}
		seen[addr] = true
		out = append(out, netip.PrefixFrom(addr, 32))
	}
	return out
}

func (s *TunnelService) Stop(ctx context.Context, _ *hcommon.Empty) (*TunnelResponse, error) {
	workDir, _ := ensureTunnelWorkDir()
	s.mu.Lock()
	s.hostsGen++ // invalidate any in-flight async hosts-override write
	box := s.box
	s.box = nil
	s.mu.Unlock()
	if box == nil {
		restoreDNSOverride(workDir)
		return &TunnelResponse{
			Message: "Not Started",
		}, nil
	}
	err := box.Close()
	restoreDNSOverride(workDir)
	if err != nil {
		return &TunnelResponse{
			Message: err.Error(),
		}, err
	}

	return &TunnelResponse{
		Message: "OK",
	}, nil
}

func (s *TunnelService) Status(ctx context.Context, _ *hcommon.Empty) (*TunnelResponse, error) {
	return &TunnelResponse{
		Message: "Not Implemented",
	}, nil
}

func (s *TunnelService) Exit(ctx context.Context, _ *hcommon.Empty) (*TunnelResponse, error) {
	workDir, _ := ensureTunnelWorkDir()
	s.mu.Lock()
	s.hostsGen++ // invalidate any in-flight async hosts-override write
	box := s.box
	s.box = nil
	s.mu.Unlock()
	if box != nil {
		box.Close()
	}
	restoreDNSOverride(workDir)
	go func() {
		<-time.After(time.Second * 1)
		os.Exit(0)
	}()
	return &TunnelResponse{
		Message: "OK",
	}, nil
}
