package tunnelservice

import (
	"context"
	"fmt"
	"net"
	"net/netip"
	"os"
	"path/filepath"
	"time"

	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/option"

	hcommon "github.com/hiddify/hiddify-core/v2/hcommon"
	"github.com/hiddify/hiddify-core/v2/hcore"
)

type TunnelService struct {
	UnimplementedTunnelServiceServer
	box *libbox.BoxService
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
		return &TunnelResponse{
			Message: err.Error(),
		}, err
	}
	s.box = instance
	// Hosts/DNS maintenance must not block the Start RPC (client budget is
	// tight). Run after TUN is up so connect can succeed first.
	go func(dir string) {
		restoreDNSOverride(dir)
		applyPublicDNSOverride(dir)
	}(workDir)

	return &TunnelResponse{
		Message: "OK",
	}, err
}

func makeTunnelConfig(in *TunnelStartRequest, workDir string) option.Options {
	ips := []netip.Prefix{netip.MustParsePrefix("172.20.0.1/30")}
	if in.Ipv6 {
		ips = append(ips, netip.MustParsePrefix("fdfe:dcba:9876::1/126"))
	}
	routeExclude := []netip.Prefix{
		netip.MustParsePrefix("10.0.0.0/8"),
		netip.MustParsePrefix("172.16.0.0/12"),
		netip.MustParsePrefix("192.168.0.0/16"),
		netip.MustParsePrefix("127.0.0.0/8"),
		netip.MustParsePrefix("169.254.0.0/16"),
		netip.MustParsePrefix("3.3.0.0/16"),
	}
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
		Log: &option.LogOptions{Level: "warn"},
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
					Stack:                  in.Stack,
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
			Rules: []option.Rule{
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
						IPCIDR:   directCIDRs,
						Outbound: "direct-out",
					},
				},
				{
					Type: C.RuleTypeDefault,
					DefaultOptions: option.DefaultRule{
						RuleSet:  []string{"geosite-cn", "geoip-cn"},
						Outbound: "direct-out",
					},
				},
				{
					// Fallback while rule-sets are still downloading.
					Type: C.RuleTypeDefault,
					DefaultOptions: option.DefaultRule{
						DomainSuffix: []string{
							".cn",
							".中国",
							"baidu.com",
							"bdstatic.com",
							"bcebos.com",
							"bilibili.com",
							"bilivideo.com",
							"iqiyi.com",
							"youku.com",
							"163.com",
							"126.com",
							"127.net",
							"netease.com",
							"zhihu.com",
							"zhimg.com",
							"douyin.com",
							"tiktokv.com",
							"bytedance.com",
							"byteimg.com",
							"pstatp.com",
							"snssdk.com",
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
			},
		},
		Experimental: &option.ExperimentalOptions{
			CacheFile: &option.CacheFileOptions{
				Enabled: true,
				Path:    filepath.Join(workDir, "cache.db"),
			},
		},
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
	if s.box == nil {
		restoreDNSOverride(workDir)
		return &TunnelResponse{
			Message: "Not Started",
		}, nil
	}
	err := s.box.Close()
	if err != nil {
		restoreDNSOverride(workDir)
		return &TunnelResponse{
			Message: err.Error(),
		}, err
	}
	s.box = nil
	restoreDNSOverride(workDir)

	return &TunnelResponse{
		Message: "OK",
	}, err
}

func (s *TunnelService) Status(ctx context.Context, _ *hcommon.Empty) (*TunnelResponse, error) {
	return &TunnelResponse{
		Message: "Not Implemented",
	}, nil
}

func (s *TunnelService) Exit(ctx context.Context, _ *hcommon.Empty) (*TunnelResponse, error) {
	workDir, _ := ensureTunnelWorkDir()
	if s.box != nil {
		s.box.Close()
		s.box = nil
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
