package hcore

import (
	"strings"
	"sync"

	"github.com/hiddify/hiddify-core/v2/config"
	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing/common/observable"
)

type HiddifyInstance struct {
	Box            *libbox.BoxService
	HiddifyOptions *config.HiddifyOptions
	// activeConfigPath string
	CoreLogFactory            log.Factory
	coreInfoObserver          *observable.Observer[*CoreInfoResponse]
	CoreState                 CoreStates
	logObserver               *observable.Observer[*LogMessage]
	systemInfoObserver        *observable.Observer[*SystemInfo]
	outboundsInfoObserver     *observable.Observer[*OutboundGroupList]
	mainOutboundsInfoObserver *observable.Observer[*OutboundGroupList]
	lock                      sync.Mutex
	globalPlatformInterface   libbox.PlatformInterface
	previousStartRequest      *StartRequest
	debug                     bool
}

// OnHiddifySettingsChanged runs after ChangeHiddifySettings applies a new
// JSON blob. The privileged tunnel uses this to refresh office-media process
// routing without restarting the GUI core (which would drop the session).
var OnHiddifySettingsChanged func()

// OfficeMediaProxyEnabled reports whether selected Mac apps should be pinned
// to the selected node.
func OfficeMediaProxyEnabled() bool {
	if static.HiddifyOptions == nil {
		return false
	}
	return static.HiddifyOptions.OfficeMediaProxy
}

// OfficeMediaApps returns .app bundle folder names (no suffix) whose
// processes should be pinned to the node when OfficeMediaProxy is on.
func OfficeMediaApps() []string {
	if static.HiddifyOptions == nil {
		return nil
	}
	return static.HiddifyOptions.OfficeMediaApps
}

func officeMediaFingerprint() (bool, string) {
	if static.HiddifyOptions == nil {
		return false, ""
	}
	return static.HiddifyOptions.OfficeMediaProxy, strings.Join(static.HiddifyOptions.OfficeMediaApps, "\x1f")
}

var static = &HiddifyInstance{
	coreInfoObserver:          NewObserver[*CoreInfoResponse](1),
	CoreState:                 CoreStates_STOPPED,
	logObserver:               NewObserver[*LogMessage](1),
	systemInfoObserver:        NewObserver[*SystemInfo](1),
	outboundsInfoObserver:     NewObserver[*OutboundGroupList](1),
	mainOutboundsInfoObserver: NewObserver[*OutboundGroupList](1),
}
