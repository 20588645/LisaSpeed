package tunnelservice

import (
	"fmt"
	"net"
	"net/netip"

	"github.com/hiddify/hiddify-core/v2/hcore"
	hutils "github.com/hiddify/hiddify-core/v2/hutils"
	"github.com/hiddify/hiddify-core/v2/service_manager"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/option"
)

// autoActivateService strips TUN from the GUI process config when the process
// cannot create a utun device, then starts the privileged HiddifyCli helper.
// This replaces the old admin_service_vpn extension path, which is not wired
// in v3 (service_manager.Register for extensions is commented out).
type autoActivateService struct {
	req *TunnelStartRequest
}

func (s *autoActivateService) Init() error    { return nil }
func (s *autoActivateService) Dispose() error { return nil }

func (s *autoActivateService) OnMainServicePreStart(singconfig *option.Options) error {
	s.req = nil
	if hutils.TunAllowed() {
		return nil
	}

	var tunOpts *option.TunInboundOptions
	newInbounds := make([]option.Inbound, 0, len(singconfig.Inbounds))
	for _, inb := range singconfig.Inbounds {
		if inb.Type == C.TypeTun {
			opts := inb.TunOptions
			tunOpts = &opts
			continue
		}
		newInbounds = append(newInbounds, inb)
	}
	if tunOpts == nil {
		return nil
	}
	singconfig.Inbounds = newInbounds

	var serverPort int32 = 12334
	username := ""
	password := ""
	for _, inb := range singconfig.Inbounds {
		switch inb.Type {
		case C.TypeMixed:
			serverPort = int32(inb.MixedOptions.ListenPort)
		case C.TypeSOCKS:
			serverPort = int32(inb.SocksOptions.ListenPort)
			if len(inb.SocksOptions.Users) > 0 {
				username = inb.SocksOptions.Users[0].Username
				password = inb.SocksOptions.Users[0].Password
			}
		}
	}

	stack := tunOpts.Stack
	if stack == "" {
		stack = "gvisor"
	}
	// TunnelStartRequest has no spare fields; piggy-back flags on Stack.
	if hcore.OfficeMediaProxyEnabled() {
		stack += officeMediaStackFlag
		stack += encodeOfficeMediaApps(hcore.OfficeMediaApps())
	}
	for _, ip := range collectProxyDialIPs(singconfig) {
		stack += excludeStackPrefix + ip
	}

	s.req = &TunnelStartRequest{
		Ipv6:                   true,
		ServerPort:             serverPort,
		ServerUsername:         username,
		ServerPassword:         password,
		StrictRoute:            tunOpts.StrictRoute,
		Stack:                  stack,
		EndpointIndependentNat: tunOpts.EndpointIndependentNat,
	}
	fmt.Printf("TUN inbound stripped; will activate privileged tunnel service on port %d\n", serverPort)
	return nil
}

func (s *autoActivateService) OnMainServiceStart() error {
	if s.req == nil {
		return nil
	}
	fmt.Printf("Activating privileged tunnel service for TUN mode\n")
	if err := ActivateTunnelService(s.req); err != nil {
		return fmt.Errorf("failed to activate tunnel service: %w", err)
	}
	return nil
}

func (s *autoActivateService) OnMainServiceClose() error {
	if s.req == nil {
		return nil
	}
	err := DeactivateTunnelService()
	s.req = nil
	return err
}

func reloadTunnelOfficeMedia() {
	if autoActivate.req == nil {
		return
	}
	next := applyOfficeMediaToStack(autoActivate.req.Stack, hcore.OfficeMediaProxyEnabled(), hcore.OfficeMediaApps())
	if next == autoActivate.req.Stack {
		return
	}
	autoActivate.req.Stack = next
	fmt.Printf("Reloading privileged tunnel for office-media change\n")
	if err := reloadTunnelRequest(autoActivate.req); err != nil {
		fmt.Printf("office-media tunnel reload failed: %v\n", err)
	}
}

var autoActivate = &autoActivateService{}

func init() {
	service_manager.Register(autoActivate)
	hcore.OnHiddifySettingsChanged = reloadTunnelOfficeMedia
}

// collectProxyDialIPs returns IPv4 addresses the GUI core will dial for
// proxy outbounds. Those must be excluded from TUN AutoRoute; otherwise the
// node IP is captured by utun and VLESS/VMess loops through mixed-in
// (tls: protocol is shutdown / i/o timeout to the node port).
func collectProxyDialIPs(opt *option.Options) []string {
	if opt == nil {
		return nil
	}
	seen := map[netip.Addr]bool{}
	var out []string
	add := func(host string) {
		if host == "" || host == "127.0.0.1" || host == "localhost" || host == "::1" {
			return
		}
		if addr, err := netip.ParseAddr(host); err == nil {
			if addr.Is4() && !seen[addr] {
				seen[addr] = true
				out = append(out, addr.String())
			}
			return
		}
		ips, err := net.LookupIP(host)
		if err != nil {
			return
		}
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
			out = append(out, addr.String())
		}
	}
	for _, ob := range opt.Outbounds {
		add(outboundServerHost(ob))
	}
	return out
}

func outboundServerHost(ob option.Outbound) string {
	switch ob.Type {
	case C.TypeVLESS:
		return ob.VLESSOptions.Server
	case C.TypeVMess:
		return ob.VMessOptions.Server
	case C.TypeTrojan:
		return ob.TrojanOptions.Server
	case C.TypeShadowsocks:
		return ob.ShadowsocksOptions.Server
	case C.TypeHysteria2:
		return ob.Hysteria2Options.Server
	case C.TypeHysteria:
		return ob.HysteriaOptions.Server
	case C.TypeTUIC:
		return ob.TUICOptions.Server
	case C.TypeHTTP:
		return ob.HTTPOptions.Server
	case C.TypeSOCKS:
		return ob.SocksOptions.Server
	case C.TypeSSH:
		return ob.SSHOptions.Server
	default:
		return ""
	}
}
