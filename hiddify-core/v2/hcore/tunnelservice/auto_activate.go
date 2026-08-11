package tunnelservice

import (
	"fmt"

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

func init() {
	service_manager.Register(&autoActivateService{})
}
