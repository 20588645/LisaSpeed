//go:build !darwin

package tunnelservice

func applyPublicDNSOverride(workDir string) {}

func restoreDNSOverride(workDir string) {}
