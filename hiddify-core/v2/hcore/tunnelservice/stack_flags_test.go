package tunnelservice

import (
	"net/netip"
	"testing"
)

func TestParseTunnelStackAppsRoundTrip(t *testing.T) {
	encoded := "gvisor" + officeMediaStackFlag + encodeOfficeMediaApps([]string{
		"哔哩哔哩",
		"抖音",
		"汽水音乐.app",
		"LisaSpeed",
		"",
		"抖音",
	}) + excludeStackPrefix + "192.220.58.72"

	got := parseTunnelStack(encoded)
	if got.stack != "gvisor" {
		t.Fatalf("stack = %q", got.stack)
	}
	if !got.officeMedia {
		t.Fatal("expected office-media")
	}
	if len(got.apps) != 3 || got.apps[0] != "哔哩哔哩" || got.apps[1] != "抖音" || got.apps[2] != "汽水音乐" {
		t.Fatalf("apps = %#v", got.apps)
	}
	if !got.appsSpecified {
		t.Fatal("expected appsSpecified")
	}
	if len(got.extraExclude) != 1 || got.extraExclude[0] != netip.MustParsePrefix("192.220.58.72/32") {
		t.Fatalf("extraExclude = %#v", got.extraExclude)
	}
}

func TestParseTunnelStackLegacyDefaults(t *testing.T) {
	got := parseTunnelStack("gvisor" + officeMediaStackFlag)
	apps := officeMediaAppsFromStack(got)
	if got.appsSpecified || len(apps) != 0 {
		t.Fatalf("legacy unspecified apps = %#v specified=%v", apps, got.appsSpecified)
	}
}

func TestParseTunnelStackEmptySelection(t *testing.T) {
	got := parseTunnelStack("gvisor" + officeMediaStackFlag + encodeOfficeMediaApps(nil))
	apps := officeMediaAppsFromStack(got)
	if !got.appsSpecified || len(apps) != 0 {
		t.Fatalf("empty selection apps = %#v specified=%v", apps, got.appsSpecified)
	}
}

func TestApplyOfficeMediaToStackToggle(t *testing.T) {
	on := "gvisor" + officeMediaStackFlag + encodeOfficeMediaApps([]string{"哔哩哔哩"}) + excludeStackPrefix + "192.220.58.72"
	off := applyOfficeMediaToStack(on, false, nil)
	got := parseTunnelStack(off)
	if got.stack != "gvisor" {
		t.Fatalf("stack = %q", got.stack)
	}
	if got.officeMedia || len(got.apps) != 0 {
		t.Fatalf("expected office-media off, got %#v", got)
	}
	if len(got.extraExclude) != 1 {
		t.Fatalf("extraExclude = %#v", got.extraExclude)
	}
	back := applyOfficeMediaToStack(off, true, []string{"抖音", "汽水音乐"})
	got = parseTunnelStack(back)
	if !got.officeMedia || len(got.apps) != 2 || got.apps[0] != "抖音" || got.apps[1] != "汽水音乐" {
		t.Fatalf("re-enabled apps = %#v", got.apps)
	}
}

func TestOfficeMediaProxyRulesStayOnProcess(t *testing.T) {
	rules := officeMediaProxyRules([]string{"哔哩哔哩"})
	if len(rules) == 0 {
		t.Fatal("expected process rules")
	}
	for _, r := range rules {
		if len(r.DefaultOptions.DomainSuffix) > 0 || len(r.DefaultOptions.DomainKeyword) > 0 {
			t.Fatalf("domain-wide office-media rules should be gone: %#v", r.DefaultOptions)
		}
	}
}
