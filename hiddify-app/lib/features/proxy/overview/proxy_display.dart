import 'package:hiddify/features/proxy/overview/proxy_list_filter.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';

final _flagEmoji = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
final _vendorId = RegExp(r'^[A-Za-z]?[_\-]?\d{8,}(?:-\d+)?(?:\s+|[-_])');
final _protocolSlug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

const _countryZh = {
  'CN': '中国',
  'HK': '香港',
  'MO': '澳门',
  'TW': '台湾',
  'US': '美国',
  'JP': '日本',
  'KR': '韩国',
  'SG': '新加坡',
  'GB': '英国',
  'DE': '德国',
  'FR': '法国',
  'NL': '荷兰',
  'AU': '澳大利亚',
  'CA': '加拿大',
  'IN': '印度',
  'RU': '俄罗斯',
  'TR': '土耳其',
  'VN': '越南',
  'TH': '泰国',
  'MY': '马来西亚',
  'PH': '菲律宾',
  'ID': '印尼',
  'AE': '阿联酋',
  'BR': '巴西',
};

String proxyRemark(OutboundInfo proxy) =>
    proxy.tagDisplay.trim().isNotEmpty ? proxy.tagDisplay : proxy.tag;

/// Country for the flag. Only url-test geo — remark 🇨🇳 is often pasted onto every node.
String proxyFlagCountryCode(OutboundInfo proxy) => _isoCountry(proxy.ipinfo.countryCode) ?? '';

String proxyDisplayTitle(
  OutboundInfo proxy, {
  required bool chinese,
  required String autoLabel,
}) {
  if (isInjectedAutoGroup(proxy)) return autoLabel;
  return proxyTitleFromParts(
    remark: proxyRemark(proxy),
    type: proxy.type,
    countryCode: proxyFlagCountryCode(proxy),
    chinese: chinese,
  );
}

String proxyTitleFromParts({
  required String remark,
  required String type,
  required String countryCode,
  required bool chinese,
}) {
  final stripped = stripProxyVendorNoise(remark);
  final protocol = proxyProtocolLabel(remark, type);
  final countryLabel = countryName(countryCode, chinese: chinese);
  if (_protocolSlug.hasMatch(stripped.toLowerCase()) && protocol != null) {
    if (countryLabel != null) return '$countryLabel · $protocol';
    return protocol;
  }
  if (stripped.isEmpty) {
    if (countryLabel != null && protocol != null) return '$countryLabel · $protocol';
    return protocol ?? remark;
  }
  return stripped;
}

String? countryName(String code, {required bool chinese}) {
  final cc = _isoCountry(code);
  if (cc == null) return null;
  if (!chinese) return cc;
  return _countryZh[cc] ?? cc;
}

/// Tunnel protocols LisaSpeed actually uses are encrypted. urltest/select
/// groups inherit that; don't show「明文」just because isSecure was never filled.
bool proxyLooksEncrypted(OutboundInfo proxy) {
  if (proxy.isSecure) return true;
  if (isInjectedAutoGroup(proxy) || proxy.isGroup) return true;
  return proxyProtocolLabel(proxyRemark(proxy), proxy.type) != null;
}

String proxyDelayLabel(
  int delay, {
  required String testing,
  required String timeout,
}) {
  if (delay <= 0) return testing;
  if (delay >= 65000) return timeout;
  return '$delay ms';
}

String? proxyProtocolLabel(String tag, String type) {
  final stripped = stripProxyVendorNoise(tag).toLowerCase().replaceAll('_', '-');
  return _protocolFromToken(stripped) ?? _protocolFromToken(type.toLowerCase());
}

String stripProxyVendorNoise(String raw) {
  return raw.trim().replaceAll(_flagEmoji, '').trim().replaceFirst(_vendorId, '').trim();
}

String? _isoCountry(String? raw) {
  final cc = raw?.trim().toUpperCase() ?? '';
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return null;
  return cc;
}

String? _protocolFromToken(String token) {
  if (token.isEmpty) return null;
  if (token.contains('shadowsocks') || token == 'ss') return 'Shadowsocks';
  if (token.contains('hysteria2') || token.contains('hy2')) return 'Hysteria2';
  if (token.contains('hysteria')) return 'Hysteria';
  if (token.contains('tuic')) return 'TUIC';
  if (token.contains('wireguard') || token == 'wg') return 'WireGuard';
  if (token.contains('trojan')) return 'Trojan';
  if (token.contains('grpc') && token.contains('reality')) return 'gRPC Reality';
  if (token.contains('grpc')) return 'gRPC';
  if (token.contains('reality') || token.contains('xtls')) return 'Reality';
  if (token.contains('vmess') && token.contains('ws')) return 'VMess WS';
  if (token.contains('vmess')) return 'VMess';
  if (token.contains('vless') && token.contains('ws')) return 'VLESS WS';
  if (token.contains('vless')) return 'VLESS';
  return null;
}
