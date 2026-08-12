//go:build darwin

package tunnelservice

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const (
	dnsStateFileName = "dns-override.state"
	hostsMarkerBegin = "# BEGIN LisaSpeed-poison-override"
	hostsMarkerEnd   = "# END LisaSpeed-poison-override"
	hostsPath        = "/etc/hosts"
)

// Domains commonly poisoned by corporate DNS to 127.0.0.1 / 0.0.0.0 sinkholes.
// Only loopback/null poisoning needs this list: such traffic never enters the
// TUN (it dials lo0), so SNI sniffing cannot rescue it. Fake-public poisoning
// is already handled by sniff + geoip. Each host is resolved via 8.8.8.8 and
// skipped if it returns nothing, so extra entries are harmless.
var poisonOverrideHosts = []string{
	// X / Twitter
	"x.com",
	"www.x.com",
	"twitter.com",
	"www.twitter.com",
	"api.x.com",
	"api.twitter.com",
	"t.co",
	"abs.twimg.com",
	"pbs.twimg.com",
	"video.twimg.com",
	// Instagram (apex poisoned to 127.0.0.1)
	"instagram.com",
	"www.instagram.com",
	"i.instagram.com",
	"graph.instagram.com",
	// Telegram (t.me poisoned to 127.0.0.1)
	"t.me",
	"telegram.org",
	"www.telegram.org",
	"web.telegram.org",
	"api.telegram.org",
	"core.telegram.org",
	// GitHub raw/objects (poisoned to 0.0.0.0; breaks browser + git)
	"raw.githubusercontent.com",
	"objects.githubusercontent.com",
	"gist.githubusercontent.com",
}

// applyPublicDNSOverride installs /etc/hosts overrides for DNS-poisoned
// domains (resolved via 8.8.8.8). This does NOT replace system DNS, so
// EasyConnect/corp resolvers keep working for everything else. Hosts file
// entries take precedence over DNS, so x.com stops resolving to 127.0.0.1.
func applyPublicDNSOverride(workDir string) {
	_ = workDir
	_ = applyPoisonHostsOverride()
}

func restoreDNSOverride(workDir string) {
	_ = removePoisonHostsOverride()

	path := filepath.Join(workDir, dnsStateFileName)
	data, err := os.ReadFile(path)
	if err != nil {
		for _, svc := range listPhysicalNetworkServices() {
			cur := getDNSServers(svc)
			if looksLikeOverrideDNS(cur) {
				_ = setDNSServers(svc, []string{"Empty"})
			}
		}
		flushDNSCache()
		return
	}
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) != 2 || parts[0] == "" {
			continue
		}
		svc := parts[0]
		servers := strings.Fields(parts[1])
		if len(servers) == 0 {
			servers = []string{"Empty"}
		}
		_ = setDNSServers(svc, servers)
	}
	_ = os.Remove(path)
	flushDNSCache()
}

func applyPoisonHostsOverride() error {
	var body strings.Builder
	body.WriteString(hostsMarkerBegin + "\n")
	for _, host := range poisonOverrideHosts {
		ips := lookupAViaDig(host)
		if len(ips) == 0 {
			continue
		}
		for _, ip := range ips {
			body.WriteString(ip)
			body.WriteByte(' ')
			body.WriteString(host)
			body.WriteByte('\n')
			// Corporate DNS often poisons AAAA to ::1; browsers prefer IPv6 and
			// then fail. IPv4-mapped AAAA overrides that without needing real AAAA.
			body.WriteString("::ffff:")
			body.WriteString(ip)
			body.WriteByte(' ')
			body.WriteString(host)
			body.WriteByte('\n')
		}
	}
	body.WriteString(hostsMarkerEnd + "\n")
	if strings.Count(body.String(), "\n") <= 2 {
		return fmt.Errorf("no public A records for poison overrides")
	}

	raw, err := os.ReadFile(hostsPath)
	if err != nil {
		return err
	}
	base := stripHostsBlock(string(raw))
	out := strings.TrimRight(base, "\n") + "\n\n" + body.String()
	if err := os.WriteFile(hostsPath, []byte(out), 0o644); err != nil {
		return err
	}
	flushDNSCache()
	return nil
}

func removePoisonHostsOverride() error {
	raw, err := os.ReadFile(hostsPath)
	if err != nil {
		return err
	}
	out := stripHostsBlock(string(raw))
	if out == string(raw) {
		return nil
	}
	if err := os.WriteFile(hostsPath, []byte(strings.TrimRight(out, "\n")+"\n"), 0o644); err != nil {
		return err
	}
	flushDNSCache()
	return nil
}

func stripHostsBlock(text string) string {
	start := strings.Index(text, hostsMarkerBegin)
	if start < 0 {
		return text
	}
	end := strings.Index(text[start:], hostsMarkerEnd)
	if end < 0 {
		return text[:start]
	}
	end = start + end + len(hostsMarkerEnd)
	for end < len(text) && (text[end] == '\n' || text[end] == '\r') {
		end++
	}
	return text[:start] + text[end:]
}

func lookupAViaDig(host string) []string {
	// Keep each lookup short; Start path used to block on these and hit RPC deadlines.
	out, err := exec.Command("dig", "+time=1", "+tries=1", "+short", "@8.8.8.8", host, "A").Output()
	if err != nil {
		return nil
	}
	var ips []string
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if ip := net.ParseIP(line); ip != nil && ip.To4() != nil {
			ips = append(ips, line)
		}
		if len(ips) >= 4 {
			break
		}
	}
	return ips
}

func looksLikeOverrideDNS(servers []string) bool {
	for _, s := range servers {
		if s == "8.8.8.8" || s == "1.1.1.1" || s == "8.8.4.4" || s == "1.0.0.1" ||
			strings.HasPrefix(s, "172.19.") || strings.HasPrefix(s, "172.20.") || strings.HasPrefix(s, "198.18.") {
			return true
		}
	}
	return false
}

func listPhysicalNetworkServices() []string {
	var out []string
	for _, svc := range listNetworkServices() {
		if isVPNLikeService(svc) {
			continue
		}
		out = append(out, svc)
	}
	return out
}

func isVPNLikeService(name string) bool {
	n := strings.ToLower(name)
	needles := []string{
		"vpn", "easyconnect", "sangfor", "ruijie", "ssl", "utun",
		"ipsec", "wireguard", "tunnelblick", "openvpn", "cisco", "anyconnect",
	}
	for _, needle := range needles {
		if strings.Contains(n, needle) {
			return true
		}
	}
	return false
}

func listNetworkServices() []string {
	out, err := exec.Command("networksetup", "-listallnetworkservices").Output()
	if err != nil {
		return nil
	}
	var services []string
	scanner := bufio.NewScanner(strings.NewReader(string(out)))
	first := true
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if first {
			first = false
			continue
		}
		if line == "" || strings.HasPrefix(line, "*") {
			continue
		}
		services = append(services, line)
	}
	return services
}

func getDNSServers(service string) []string {
	out, err := exec.Command("networksetup", "-getdnsservers", service).Output()
	if err != nil {
		return nil
	}
	text := strings.TrimSpace(string(out))
	if text == "" || strings.Contains(text, "aren't any DNS Servers") || strings.Contains(text, "There aren't any") {
		return nil
	}
	return strings.Fields(text)
}

func setDNSServers(service string, servers []string) error {
	args := append([]string{"-setdnsservers", service}, servers...)
	cmd := exec.Command("networksetup", args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("networksetup -setdnsservers %s: %w (%s)", service, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func flushDNSCache() {
	_ = exec.Command("dscacheutil", "-flushcache").Run()
	_ = exec.Command("killall", "-HUP", "mDNSResponder").Run()
}
