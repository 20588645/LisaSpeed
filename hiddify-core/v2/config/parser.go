package config

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/hiddify/ray2sing/ray2sing"
	"github.com/sagernet/sing-box/experimental/libbox"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/batch"
	SJ "github.com/sagernet/sing/common/json"
	"github.com/xmdhs/clash2singbox/convert"
	"github.com/xmdhs/clash2singbox/model/clash"
	"github.com/xmdhs/clash2singbox/model/singbox"
	"gopkg.in/yaml.v3"
)

//go:embed config.json.template
var configByte []byte

func ParseConfig(path string, debug bool) ([]byte, error) {
	content, err := os.ReadFile(path)
	os.Chdir(filepath.Dir(path))
	if err != nil {
		return nil, err
	}
	return ParseConfigContent(string(content), debug, nil, false)
}

func ParseConfigContentToOptions(contentstr string, debug bool, configOpt *HiddifyOptions, fullConfig bool) (*option.Options, error) {
	content, err := ParseConfigContent(contentstr, debug, configOpt, fullConfig)
	if err != nil {
		return nil, err
	}
	var options option.Options
	err = json.Unmarshal(content, &options)
	if err != nil {
		return nil, err
	}
	return &options, nil
}

func ParseConfigContent(contentstr string, debug bool, configOpt *HiddifyOptions, fullConfig bool) ([]byte, error) {
	if configOpt == nil {
		configOpt = DefaultHiddifyOptions()
	}
	content := []byte(contentstr)
	var jsonObj map[string]interface{} = make(map[string]interface{})

	fmt.Printf("Convert using json\n")
	var tmpJsonResult any
	jsonDecoder := json.NewDecoder(SJ.NewCommentFilter(bytes.NewReader(content)))
	if err := jsonDecoder.Decode(&tmpJsonResult); err == nil {
		if tmpJsonObj, ok := tmpJsonResult.(map[string]interface{}); ok {
			if tmpJsonObj["outbounds"] == nil {
				jsonObj["outbounds"] = []interface{}{jsonObj}
			} else {
				if fullConfig || (configOpt != nil && configOpt.EnableFullConfig) {
					jsonObj = tmpJsonObj
				} else {
					jsonObj["outbounds"] = tmpJsonObj["outbounds"]
				}
			}
		} else if jsonArray, ok := tmpJsonResult.([]map[string]interface{}); ok {
			jsonObj["outbounds"] = jsonArray
		} else {
			return nil, fmt.Errorf("[SingboxParser] Incorrect Json Format")
		}

		newContent, _ := json.MarshalIndent(jsonObj, "", "  ")

		return patchConfig(newContent, "SingboxParser", configOpt)
	}

	if looksLikeClashYAML(content) {
		if out, recognized, err := parseClashConfig(content, configOpt); recognized {
			return out, err
		}
	}

	v2rayStr, err := ray2sing.Ray2Singbox(string(content), configOpt.UseXrayCoreWhenPossible)
	if err == nil {
		return patchConfig([]byte(v2rayStr), "V2rayParser", configOpt)
	}
	fmt.Printf("Convert using clash\n")
	if out, recognized, err := parseClashConfig(content, configOpt); recognized {
		return out, err
	}

	return nil, fmt.Errorf("unable to determine config format")
}

var (
	clashQuotedIntKeys = regexp.MustCompile(`(?i)(max-connections|min-streams|max-streams):\s*['"](\d+)['"]`)
	clashEmptyFlow     = regexp.MustCompile(`(?i)\bflow:\s*,`)
	clashYAMLKey       = regexp.MustCompile(`(?m)^(mixed-port|proxies|proxy-providers|proxy-groups):`)
)

func looksLikeClashYAML(content []byte) bool {
	s := bytes.TrimSpace(content)
	if len(s) == 0 || s[0] == '{' || s[0] == '[' {
		return false
	}
	return clashYAMLKey.Match(s)
}

// Clash Meta panel exports quote smux integers (`max-connections: '8'`) and
// put SHA256 cert pins in `fingerprint`. clash2singbox unmarshals those ints
// as int and maps fingerprint to uTLS, so the whole document used to fail
// with "unable to determine config format".
func sanitizeClashYAML(content []byte) []byte {
	s := string(content)
	s = clashQuotedIntKeys.ReplaceAllString(s, "$1: $2")
	s = clashEmptyFlow.ReplaceAllString(s, `flow: "",`)
	return []byte(s)
}

func parseClashConfig(content []byte, configOpt *HiddifyOptions) ([]byte, bool, error) {
	fmt.Printf("Convert using clash\n")
	clashObj := clash.Clash{}
	if err := yaml.Unmarshal(sanitizeClashYAML(content), &clashObj); err != nil {
		return nil, false, err
	}
	if len(clashObj.Proxies) == 0 {
		if looksLikeClashYAML(content) {
			return nil, true, fmt.Errorf("[ClashParser] no inline proxies; proxy-providers are not imported")
		}
		return nil, false, nil
	}
	converted, convErr := convert.Clash2sing(clashObj)
	converted = cleanupClashOutbounds(converted)
	if len(converted) == 0 {
		if convErr != nil {
			return nil, true, fmt.Errorf("[ClashParser] converting clash to sing-box error: %w", convErr)
		}
		return nil, true, fmt.Errorf("[ClashParser] no outbounds found")
	}
	output, err := convert.Patch(configByte, converted, "", "", nil)
	if err != nil {
		return nil, true, fmt.Errorf("[ClashParser] patching clash config error: %w", err)
	}
	out, err := patchConfig(output, "ClashParser", configOpt)
	return out, true, err
}

func cleanupClashOutbounds(sl []singbox.SingBoxOut) []singbox.SingBoxOut {
	out := sl[:0]
	for _, item := range sl {
		if item.Heartbeat == "0ms" || item.Heartbeat == "0s" || item.Heartbeat == "0" {
			item.Heartbeat = ""
		}
		if item.TLS != nil && item.TLS.Utls != nil {
			fp := item.TLS.Utls.Fingerprint
			if fp == "" || strings.Contains(fp, ":") || isHexCertPin(fp) {
				item.TLS.Utls = nil
			}
		}
		out = append(out, item)
	}
	return out
}

func isHexCertPin(fp string) bool {
	if len(fp) < 20 {
		return false
	}
	for _, r := range fp {
		switch {
		case r >= '0' && r <= '9', r >= 'a' && r <= 'f', r >= 'A' && r <= 'F', r == ':':
		default:
			return false
		}
	}
	return true
}

func patchConfig(content []byte, name string, configOpt *HiddifyOptions) ([]byte, error) {
	options := option.Options{}
	err := json.Unmarshal(content, &options)
	if err != nil {
		return nil, fmt.Errorf("[SingboxParser] unmarshal error: %w", err)
	}
	b, _ := batch.New(context.Background(), batch.WithConcurrencyNum[*option.Outbound](2))
	for _, base := range options.Outbounds {
		out := base
		b.Go(base.Tag, func() (*option.Outbound, error) {
			err := patchWarp(&out, configOpt, false, nil)
			if err != nil {
				return nil, fmt.Errorf("[Warp] patch warp error: %w", err)
			}
			// options.Outbounds[i] = base
			return &out, nil
		})
	}
	if res, err := b.WaitAndGetResult(); err != nil {
		return nil, err
	} else {
		for i, base := range options.Outbounds {
			options.Outbounds[i] = *res[base.Tag].Value
		}
	}

	content, _ = json.MarshalIndent(options, "", "  ")

	// fmt.Printf("%s\n", content)
	return validateResult(content, name)
}

func validateResult(content []byte, name string) ([]byte, error) {
	err := libbox.CheckConfig(string(content))
	if err != nil {
		return nil, fmt.Errorf("[%s] invalid sing-box config: %w", name, err)
	}
	return content, nil
}
