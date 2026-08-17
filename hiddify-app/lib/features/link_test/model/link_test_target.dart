enum LinkTestGroup { cn, intl }

class LinkTestTarget {
  const LinkTestTarget({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.url,
    required this.group,
  });

  final String id;
  final String nameZh;
  final String nameEn;
  final String url;
  final LinkTestGroup group;

  String displayName({required bool chinese}) => chinese ? nameZh : nameEn;

  String get host {
    final uri = Uri.tryParse(url);
    return uri?.host ?? url;
  }
}

enum LinkTestFailureKind { timeout, network, tls, unknown }

class LinkTestOutcome {
  const LinkTestOutcome._({
    required this.ok,
    this.latencyMs,
    this.statusCode,
    this.failure,
    required this.viaProxy,
    required this.testedAt,
  });

  factory LinkTestOutcome.ok({required int latencyMs, required int statusCode, required bool viaProxy}) {
    return LinkTestOutcome._(
      ok: true,
      latencyMs: latencyMs,
      statusCode: statusCode,
      viaProxy: viaProxy,
      testedAt: DateTime.now(),
    );
  }

  factory LinkTestOutcome.fail(LinkTestFailureKind failure, {required bool viaProxy}) {
    return LinkTestOutcome._(ok: false, failure: failure, viaProxy: viaProxy, testedAt: DateTime.now());
  }

  final bool ok;
  final int? latencyMs;
  final int? statusCode;
  final LinkTestFailureKind? failure;
  final bool viaProxy;
  final DateTime testedAt;
}

/// VPN mixed-in is pinned to the node. Forcing domestic probes through it
/// hairpins China sites via the overseas VPS (1–4s). Real TUN traffic uses
/// geosite-cn → direct. Match that: CN = direct, overseas = mixed-in.
bool linkTestUsesProxy(LinkTestGroup group, bool connected) =>
    connected && group == LinkTestGroup.intl;
