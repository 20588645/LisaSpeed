package tunnelservice

import (
	"context"
	"fmt"
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
	option := makeTunnelConfig(in, workDir)

	instance, err := hcore.NewService(option)
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

	return &TunnelResponse{
		Message: "OK",
	}, err
}

func makeTunnelConfig(in *TunnelStartRequest, workDir string) option.Options {
	ips := []netip.Prefix{netip.MustParsePrefix("172.20.0.1/30")}
	if in.Ipv6 {
		ips = append(ips, netip.MustParsePrefix("fdfe:dcba:9876::1/126"))
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
					// macOS only accepts empty (auto) or "utunN". Custom names
					// like "HiddifyTunnel" fail with "bad tun name".
					InterfaceName: "",
					Stack:         in.Stack,
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
			Rules: []option.Rule{
				{
					// Keep Hiddify itself and company VPN clients off the
					// socks hairpin; otherwise EasyConnect/OpenVPN cannot
					// reach their gateways through a second TUN.
					DefaultOptions: option.DefaultRule{
						ProcessName: []string{
							"Hiddify.exe",
							"Hiddify",
							"HiddifyCli",
							"HiddifyCli.exe",
							"EasyConnect",
							"ECAgent",
							"ECAgentProxy",
							"EasyMonitor",
							"svpnservice",
							"openvpn",
							"Tunnelblick",
							"Bastion",
							"bh_am_pfe_tunnel",
							"WeChat",
							// Cursor already often has HTTP_PROXY=127.0.0.1:12334.
							// Letting TUN also capture it double-proxies / breaks DNS.
							"Cursor",
							"Cursor Helper",
							"Cursor Helper (Renderer)",
							"Cursor Helper (Plugin)",
							"Cursor Helper (GPU)",
						},
						Outbound: "direct-out",
					},
				},
				{
					// Private / link-local / EasyConnect (3.3.3.0/24) ranges
					// must never be forced through the overseas proxy.
					DefaultOptions: option.DefaultRule{
						IPCIDR: []string{
							"10.0.0.0/8",
							"172.16.0.0/12",
							"192.168.0.0/16",
							"127.0.0.0/8",
							"169.254.0.0/16",
							"3.3.3.0/24",
							"fc00::/7",
							"fe80::/10",
						},
						Outbound: "direct-out",
					},
				},
				{
					DefaultOptions: option.DefaultRule{
						DomainSuffix: []string{
							".cn",
							"moutaichina.com",
							"moutai.com",
							"qq.com",
							"weixin.qq.com",
							"wechat.com",
							"qcloud.com",
							"tencent.com",
							"tencent-cloud.com",
							"alicdn.com",
							"aliyuncs.com",
							"aliyun.com",
							"taobao.com",
							"jd.com",
							"gtimg.com",
							"idqqimg.com",
							"servicewechat.com",
						},
						Outbound: "direct-out",
					},
				},
			},
		},
		// PlatformLogWriter in NewService forces cachefile on; default path is
		// relative "cache.db" which lands on the read-only root volume under launchd.
		Experimental: &option.ExperimentalOptions{
			CacheFile: &option.CacheFileOptions{
				Enabled: true,
				Path:    filepath.Join(workDir, "cache.db"),
			},
		},
	}
}

func (s *TunnelService) Stop(ctx context.Context, _ *hcommon.Empty) (*TunnelResponse, error) {
	if s.box == nil {
		return &TunnelResponse{
			Message: "Not Started",
		}, nil
	}
	err := s.box.Close()
	if err != nil {
		return &TunnelResponse{
			Message: err.Error(),
		}, err
	}
	s.box = nil

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
	if s.box != nil {
		s.box.Close()
		s.box = nil
	}
	go func() {
		<-time.After(time.Second * 1)
		os.Exit(0)
	}()
	return &TunnelResponse{
		Message: "OK",
	}, nil
}
