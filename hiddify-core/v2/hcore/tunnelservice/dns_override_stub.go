//go:build !darwin

package tunnelservice

func resolvePoisonHostsBlock() (string, bool) { return "", false }

func writePoisonHostsBlock(body string) error { return nil }

func restoreDNSOverride(workDir string) {}
