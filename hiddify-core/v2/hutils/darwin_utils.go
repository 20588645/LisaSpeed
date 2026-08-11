//go:build darwin

package hutils

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/sagernet/sing-box/experimental/libbox"
)

func RedirectStderr(path string) error {
	return libbox.RedirectStderr(path)
}

func IsAdmin() bool {
	return os.Getuid() == 0
}

// TunAllowed reports whether the current process can create a TUN device.
// On macOS creating a utun interface and installing routes requires root,
// there is no capability mechanism like Linux CAP_NET_ADMIN.
func TunAllowed() bool {
	return IsAdmin()
}

// quoteForShellScript escapes a string for embedding inside the double-quoted
// `do shell script "..."` argument of an AppleScript. Two levels of quoting are
// involved: AppleScript string literal, then the shell that receives it. Wrapping
// each argument in single quotes protects the shell, and backslash-escaping the
// AppleScript metacharacters protects the literal.
func quoteForShellScript(arg string) string {
	// Wrap in single quotes for the shell; a literal single quote is closed,
	// escaped, and reopened.
	shellQuoted := "'" + strings.ReplaceAll(arg, "'", `'\''`) + "'"
	// Escape for the AppleScript double-quoted string literal.
	shellQuoted = strings.ReplaceAll(shellQuoted, `\`, `\\`)
	shellQuoted = strings.ReplaceAll(shellQuoted, `"`, `\"`)
	return shellQuoted
}

// ExecuteCmd runs executablePath with args as root.
//
// It first tries without elevation in case we are already root (the CLI running
// as a launchd daemon is), then falls back to prompting the user through
// osascript, which shows the standard macOS authentication dialog.
func ExecuteCmd(executablePath string, background bool, args ...string) (string, error) {
	cwd := filepath.Dir(executablePath)

	if IsAdmin() {
		cmd := exec.Command(executablePath, args...)
		cmd.Dir = cwd
		return runCmd(cmd, background)
	}

	quoted := make([]string, 0, len(args)+1)
	quoted = append(quoted, quoteForShellScript(executablePath))
	for _, arg := range args {
		quoted = append(quoted, quoteForShellScript(arg))
	}
	shellScript := strings.Join(quoted, " ")
	if background {
		shellScript += " > /dev/null 2>&1 &"
	}

	appleScript := fmt.Sprintf(
		`do shell script "%s" with prompt "Hiddify needs administrator access to create the VPN tunnel." with administrator privileges`,
		shellScript,
	)

	cmd := exec.Command("osascript", "-e", appleScript)
	cmd.Dir = cwd
	// osascript itself must not be backgrounded: the dialog is synchronous and we
	// need its exit status to know whether the user authenticated.
	out, err := runCmd(cmd, false)
	if err != nil {
		return out, fmt.Errorf("failed to run %s as root: %w (%s)", executablePath, err, out)
	}
	return out, nil
}

func runCmd(cmd *exec.Cmd, background bool) (string, error) {
	if background {
		if err := cmd.Start(); err != nil {
			return "", err
		}
		return "Ok", nil
	}
	out, err := cmd.CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

func Chmod(path string, mode os.FileMode) error {
	return os.Chmod(path, mode)
}
