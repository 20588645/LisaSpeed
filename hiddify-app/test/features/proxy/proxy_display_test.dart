import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

void main() {
  test('strips vendor ids and flag emoji from remarks', () {
    expect(stripProxyVendorNoise('V20260607085289-001 xtls-reality'), 'xtls-reality');
    expect(stripProxyVendorNoise('🇨🇳 V20260607085289-001 vmess-ws'), 'vmess-ws');
    expect(stripProxyVendorNoise('V20260607085289-001-grpc-reality'), 'grpc-reality');
  });

  test('flag follows url-test geo, not a 🇨🇳 pasted onto every remark', () {
    final us = OutboundInfo(
      tag: '🇨🇳 V20260607085289-001 vless-ws-tls',
      tagDisplay: '🇨🇳 V20260607085289-001 vless-ws-tls',
      type: 'vless',
      ipinfo: IpInfo(countryCode: 'US'),
    );
    expect(proxyFlagCountryCode(us), 'US');
    expect(proxyDisplayTitle(us, chinese: true, autoLabel: '自动选择'), '美国 · VLESS WS');

    final untested = OutboundInfo(
      tag: '🇨🇳 V20260607085289-001 shadowsocks',
      tagDisplay: '🇨🇳 V20260607085289-001 shadowsocks',
      type: 'shadowsocks',
    );
    expect(proxyFlagCountryCode(untested), isEmpty);
    expect(proxyDisplayTitle(untested, chinese: true, autoLabel: '自动选择'), 'Shadowsocks');
  });

  test('builds readable titles from panel ids', () {
    final node = OutboundInfo(
      tag: 'V20260607085289-001 xtls-reality',
      tagDisplay: 'V20260607085289-001 xtls-reality',
      type: 'vless',
      ipinfo: IpInfo(countryCode: 'CN'),
    );
    expect(proxyDisplayTitle(node, chinese: true, autoLabel: '自动选择'), '中国 · Reality');
    expect(proxyDisplayTitle(node, chinese: false, autoLabel: 'Auto select'), 'CN · Reality');
  });

  test('keeps already readable names', () {
    final home = OutboundInfo(tag: '美国家宽', tagDisplay: '美国家宽', type: 'vless', ipinfo: IpInfo(countryCode: 'US'));
    expect(proxyDisplayTitle(home, chinese: true, autoLabel: '自动选择'), '美国家宽');
    expect(proxyFlagCountryCode(home), 'US');
  });

  test('labels injected auto group', () {
    final auto = OutboundInfo(tag: 'auto', type: 'urltest', isGroup: true, ipinfo: IpInfo(countryCode: 'CN'));
    expect(proxyDisplayTitle(auto, chinese: true, autoLabel: '自动选择'), '自动选择');
    expect(proxyFlagCountryCode(auto), 'CN');
    expect(proxyLooksEncrypted(auto), isTrue);
  });

  test('treats common node types as encrypted even when isSecure is unset', () {
    expect(proxyLooksEncrypted(OutboundInfo(tag: 'n', type: 'vless')), isTrue);
    expect(proxyDelayLabel(0, testing: '测速中', timeout: '超时'), '测速中');
    expect(proxyDelayLabel(65535, testing: '测速中', timeout: '超时'), '超时');
  });
}
