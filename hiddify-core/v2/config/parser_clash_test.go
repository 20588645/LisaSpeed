package config

import (
	"encoding/json"
	"strings"
	"testing"
)

const clashPanelProxies = `proxies:
  - {name: "n1 xtls-reality", type: vless, server: 1.2.3.4, port: 8881, uuid: 00000000-0000-4000-8000-000000000001, network: tcp, udp: true, tls: true, flow: xtls-rprx-vision, servername: example.com, client-fingerprint: firefox, reality-opts: {public-key: iwNLqD-brqm6onCs3w063bZt7UCPXBsiWQ1NO76aSyA, short-id: ""}, smux: { enabled: false, protocol: 'h2mux', padding: false, max-connections: '8', min-streams: '16', statistic: true, only-tcp: false } }
  - {name: "n2 hysteria2", type: hysteria2, server: 1.2.3.4, port: 8882, up: "200 Mbps", down: "1000 Mbps", password: secret, sni: example.com, skip-cert-verify: true, fingerprint: 58:A9:FB:A6:B6:B1:65:69:F7:52:D0:E3:A4:79:DE:9C:B3:9C:BE:AF}
  - {name: "n3 anytls", type: anytls, server: 1.2.3.4, port: 8891, password: secret, client-fingerprint: firefox, udp: true, sni: example.com, skip-cert-verify: true }
  - {name: "n4 grpc-reality", type: vless, server: 1.2.3.4, port: 8890, uuid: 00000000-0000-4000-8000-000000000001, network: grpc, tls: true, udp: true, flow: , client-fingerprint: firefox, servername: example.com, grpc-opts: {  grpc-service-name: "grpc" }, reality-opts: { public-key: iwNLqD-brqm6onCs3w063bZt7UCPXBsiWQ1NO76aSyA, short-id: "" }, smux: { enabled: true, protocol: 'h2mux', padding: true, max-connections: '8', min-streams: '16' } }
`

func TestSanitizeClashYAMLUnquotesSmuxInts(t *testing.T) {
	got := string(sanitizeClashYAML([]byte(clashPanelProxies)))
	if strings.Contains(got, "max-connections: '8'") || strings.Contains(got, `max-connections: "8"`) {
		t.Fatalf("quoted max-connections still present")
	}
	if !strings.Contains(got, "max-connections: 8") {
		t.Fatalf("expected unquoted max-connections: 8\n%s", got)
	}
	if strings.Contains(got, "flow: ,") {
		t.Fatalf("empty flow still present")
	}
}

func TestParseClashPanelProxies(t *testing.T) {
	out, err := ParseConfigContent(clashPanelProxies, false, DefaultHiddifyOptions(), false)
	if err != nil {
		t.Fatalf("ParseConfigContent: %v", err)
	}
	var parsed map[string]any
	if err := json.Unmarshal(out, &parsed); err != nil {
		t.Fatalf("json: %v", err)
	}
	raw, _ := parsed["outbounds"].([]any)
	types := map[string]int{}
	for _, item := range raw {
		m, _ := item.(map[string]any)
		types[fmtString(m["type"])]++
	}
	if types["vless"] < 2 {
		t.Fatalf("expected at least 2 vless outbounds, got %v", types)
	}
	if types["hysteria2"] < 1 {
		t.Fatalf("expected hysteria2 outbound, got %v", types)
	}
	if types["anytls"] != 0 {
		t.Fatalf("unsupported anytls should be skipped, got %v", types)
	}
}

func TestParseClashAutoWithoutProxiesStillUnknown(t *testing.T) {
	const auto = "mixed-port: 7890\nproxies:\n\nproxy-groups:\n  - { name: x, type: select, proxies: [DIRECT] }\n"
	_, err := ParseConfigContent(auto, false, DefaultHiddifyOptions(), false)
	if err == nil || !strings.Contains(err.Error(), "no inline proxies") {
		t.Fatalf("expected missing-proxies clash error, got %v", err)
	}
}

func fmtString(v any) string {
	s, _ := v.(string)
	return s
}
