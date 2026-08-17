enum IpLineType { residential, business, isp, hosting, mobile, vpn, unknown }

enum IpPurityGrade { excellent, good, fair, poor, bad }

enum IpSceneKind { tiktok, commerce, social, ai }

enum IpSceneVerdict { perfect, tryable, avoid }

class IpPurityReport {
  const IpPurityReport({
    required this.ip,
    required this.score,
    required this.testedAt,
    required this.viaProxy,
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.isp,
    this.org,
    this.asn,
    this.asnName,
    this.lat,
    this.lon,
    this.registryCountry,
    this.networkType,
    this.deviceCount,
    this.externalRisk,
    this.native,
    this.datacenter = false,
    this.hosting = false,
    this.proxy = false,
    this.vpn = false,
    this.tor = false,
    this.abuser = false,
    this.mobile = false,
    this.sources = const [],
  });

  final String ip;
  final int score;
  final DateTime testedAt;
  final bool viaProxy;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? city;
  final String? isp;
  final String? org;
  final String? asn;
  final String? asnName;
  final double? lat;
  final double? lon;
  final String? registryCountry;
  final String? networkType;
  final int? deviceCount;
  final int? externalRisk;
  final bool? native;
  final bool datacenter;
  final bool hosting;
  final bool proxy;
  final bool vpn;
  final bool tor;
  final bool abuser;
  final bool mobile;
  final List<String> sources;

  IpPurityGrade get grade => gradeForScore(score);

  IpLineType get lineType {
    if (mobile) return IpLineType.mobile;
    if (hosting) return IpLineType.hosting;
    final type = (networkType ?? '').toLowerCase();
    if (type == 'vpn') return IpLineType.vpn;
    if (type == 'residential' || type == 'wireless') return IpLineType.residential;
    if (type == 'business' || type == 'corporate') return IpLineType.business;
    if ((isp != null && isp!.trim().isNotEmpty) || (org != null && org!.trim().isNotEmpty)) {
      return IpLineType.isp;
    }
    return IpLineType.unknown;
  }

  bool get proxyLike => proxy || vpn || tor;

  bool get nativeIp => native == true;

  bool get nativeKnown => native != null;

  String get locationLabel {
    final parts = [country, region, city].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.join(' ');
  }

  String get flagEmoji {
    final cc = countryCode?.trim().toUpperCase() ?? '';
    if (cc.length != 2) return '';
    return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 - 0x41 + c));
  }

  IpSceneVerdict verdictFor(IpSceneKind kind) {
    return sceneVerdict(
      kind: kind,
      score: score,
      proxyLike: proxyLike,
      hosting: hosting,
      abuser: abuser || tor,
      business: lineType == IpLineType.business,
    );
  }
}

IpPurityGrade gradeForScore(int score) {
  if (score >= 85) return IpPurityGrade.excellent;
  if (score >= 70) return IpPurityGrade.good;
  if (score >= 50) return IpPurityGrade.fair;
  if (score >= 30) return IpPurityGrade.poor;
  return IpPurityGrade.bad;
}

/// Higher is cleaner. Hosting is only applied after source consensus.
int computePurityScore({
  required bool hosting,
  required bool proxy,
  required bool vpn,
  required bool tor,
  required bool abuser,
  required bool mobile,
  int externalRisk = 0,
  int deviceCount = 0,
}) {
  var risk = 10;
  if (hosting) risk += 28;
  if (proxy) risk += 24;
  if (vpn) risk += 14;
  if (tor) risk += 36;
  if (abuser) risk += 20;
  if (mobile) risk -= 4;
  if (deviceCount >= 20) {
    risk += 16;
  } else if (deviceCount >= 5) {
    risk += 8;
  }
  if (externalRisk > 0) {
    final scaled = (externalRisk * 0.85).round();
    if (scaled > risk) risk = scaled;
  }
  if (!hosting && !proxy && !vpn && !tor && !abuser) {
    risk = mobile ? 10 : 12;
    if (deviceCount >= 5) risk += 6;
    if (externalRisk > 0) {
      final scaled = (externalRisk * 0.85).round();
      if (scaled > risk) risk = scaled;
    }
  }
  return (100 - risk).clamp(0, 100);
}

IpSceneVerdict sceneVerdict({
  required IpSceneKind kind,
  required int score,
  required bool proxyLike,
  required bool hosting,
  required bool abuser,
  bool business = false,
}) {
  if (abuser || (kind != IpSceneKind.ai && proxyLike && hosting)) {
    return IpSceneVerdict.avoid;
  }
  switch (kind) {
    case IpSceneKind.tiktok:
    case IpSceneKind.commerce:
    case IpSceneKind.social:
      if (business) {
        if (score >= 58 && !proxyLike) return IpSceneVerdict.tryable;
        return IpSceneVerdict.avoid;
      }
      if (score >= 80 && !proxyLike && !hosting) return IpSceneVerdict.perfect;
      if (score >= 58 && !proxyLike) return IpSceneVerdict.tryable;
      return IpSceneVerdict.avoid;
    case IpSceneKind.ai:
      if (score >= 55 && !abuser) return IpSceneVerdict.perfect;
      if (score >= 40) return IpSceneVerdict.tryable;
      return IpSceneVerdict.avoid;
  }
}

class IpPuritySnapshot {
  const IpPuritySnapshot({
    this.ip,
    this.country,
    this.countryCode,
    this.region,
    this.city,
    this.isp,
    this.org,
    this.asn,
    this.asnName,
    this.lat,
    this.lon,
    this.registryCountry,
    this.networkType,
    this.deviceCount,
    this.externalRisk,
    this.datacenter,
    this.hosting,
    this.proxy,
    this.vpn,
    this.tor,
    this.abuser,
    this.mobile,
    this.source,
  });

  final String? ip;
  final String? country;
  final String? countryCode;
  final String? region;
  final String? city;
  final String? isp;
  final String? org;
  final String? asn;
  final String? asnName;
  final double? lat;
  final double? lon;
  final String? registryCountry;
  final String? networkType;
  final int? deviceCount;
  final int? externalRisk;
  final bool? datacenter;
  final bool? hosting;
  final bool? proxy;
  final bool? vpn;
  final bool? tor;
  final bool? abuser;
  final bool? mobile;
  final String? source;
}

IpPuritySnapshot? parseIpWhoIs(Map<String, dynamic> json) {
  if (json['success'] == false) return null;
  final ip = _str(json['ip']);
  if (ip == null) return null;
  final connection = json['connection'];
  final conn = connection is Map ? Map<String, dynamic>.from(connection) : const <String, dynamic>{};
  final asnNum = conn['asn'];
  return IpPuritySnapshot(
    ip: ip,
    country: _str(json['country']),
    countryCode: _str(json['country_code']),
    region: _str(json['region']),
    city: _str(json['city']),
    isp: _str(conn['isp']) ?? _str(conn['org']),
    org: _str(conn['org']),
    asn: asnNum == null ? null : 'AS$asnNum',
    asnName: _str(conn['org']),
    lat: _num(json['latitude']),
    lon: _num(json['longitude']),
    source: 'ipwho.is',
  );
}

IpPuritySnapshot? parseIpApi(Map<String, dynamic> json) {
  if (json['status'] != null && json['status'] != 'success') return null;
  final ip = _str(json['query']) ?? _str(json['ip']);
  if (ip == null) return null;
  final asRaw = _str(json['as']);
  String? asn;
  String? asnName;
  if (asRaw != null) {
    final match = RegExp(r'^(AS\d+)\s*(.*)$').firstMatch(asRaw);
    asn = match?.group(1) ?? asRaw;
    asnName = match?.group(2)?.trim();
    if (asnName != null && asnName.isEmpty) asnName = null;
  }
  return IpPuritySnapshot(
    ip: ip,
    country: _str(json['country']),
    countryCode: _str(json['countryCode']),
    region: _str(json['regionName']),
    city: _str(json['city']),
    isp: _str(json['isp']),
    org: _str(json['org']),
    asn: asn,
    asnName: asnName ?? _str(json['asname']),
    lat: _num(json['lat']),
    lon: _num(json['lon']),
    hosting: _flag(json['hosting']),
    proxy: _flag(json['proxy']),
    mobile: _flag(json['mobile']),
    source: 'ip-api',
  );
}

IpPuritySnapshot? parseIpApiIs(Map<String, dynamic> json) {
  final ip = _str(json['ip']);
  if (ip == null) return null;
  final company = _map(json['company']);
  final asnObj = _map(json['asn']);
  final location = _map(json['location']);
  final asnNum = json['asn_num'] ?? asnObj['asn'];
  return IpPuritySnapshot(
    ip: ip,
    country: _str(location['country']),
    countryCode: _str(json['cc']) ?? _str(location['country_code']) ?? _str(location['countryCode']),
    region: _str(location['state']) ?? _str(location['region']),
    city: _str(location['city']),
    isp: _str(json['company_name']) ?? _str(company['name']),
    org: _str(json['company_name']) ?? _str(company['name']) ?? _str(json['asn_org']) ?? _str(asnObj['org']),
    asn: asnNum == null ? null : 'AS$asnNum',
    asnName: _str(json['asn_org']) ?? _str(asnObj['org']) ?? _str(asnObj['descr']),
    lat: _num(json['lat']) ?? _num(location['latitude']) ?? _num(location['lat']),
    lon: _num(json['lon']) ?? _num(location['longitude']) ?? _num(location['lon']),
    datacenter: _flag(json['is_datacenter']),
    proxy: _flag(json['is_proxy']),
    vpn: _flag(json['is_vpn']),
    tor: _flag(json['is_tor']),
    abuser: _flag(json['is_abuser']),
    mobile: _flag(json['is_mobile']),
    source: 'ipapi.is',
  );
}

IpPuritySnapshot? parseProxyCheck(Map<String, dynamic> json) {
  if (json['status'] != null && json['status'] != 'ok') return null;
  Map<String, dynamic>? block;
  String? ip;
  for (final entry in json.entries) {
    if (entry.key == 'status' || entry.key == 'message' || entry.key == 'node') continue;
    if (entry.value is Map) {
      ip = entry.key;
      block = Map<String, dynamic>.from(entry.value as Map);
      break;
    }
  }
  if (block == null || ip == null) return null;
  final type = _str(block['type']);
  final typeLower = type?.toLowerCase() ?? '';
  final devices = _map(block['devices']);
  final proxyYes = _flag(block['proxy']) || typeLower.contains('socks') || typeLower == 'http' || typeLower == 'https';
  return IpPuritySnapshot(
    ip: ip,
    country: _str(block['country']),
    countryCode: _str(block['isocode']),
    region: _str(block['region']),
    city: _str(block['city']),
    isp: _str(block['provider']),
    org: _str(block['organisation']) ?? _str(block['provider']),
    asn: _str(block['asn']),
    asnName: _str(block['provider']),
    lat: _num(block['latitude']),
    lon: _num(block['longitude']),
    networkType: type,
    deviceCount: _int(devices['address']),
    externalRisk: _int(block['risk']),
    hosting: typeLower == 'hosting' || typeLower.contains('datacenter'),
    proxy: proxyYes,
    vpn: typeLower == 'vpn',
    source: 'proxycheck',
  );
}

IpPuritySnapshot? parseRipeWhois(Map<String, dynamic> json, {String? fallbackIp}) {
  final data = _map(json['data']);
  final ip = _str(data['resource']) ?? fallbackIp;
  if (ip == null) return null;
  String? country;
  String? org;
  final records = data['records'];
  if (records is List) {
    for (final rec in records) {
      if (rec is! List) continue;
      for (final item in rec) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final key = _str(row['key'])?.toLowerCase();
        final value = _str(row['value']);
        if (value == null || key == null) continue;
        if (key == 'country' && country == null) country = value;
        if ((key == 'orgname' || key == 'organization') && org == null) org = value;
      }
    }
  }
  return IpPuritySnapshot(
    ip: ip,
    registryCountry: _normalizeCountryCode(country),
    org: org,
    source: 'ripe',
  );
}

/// ipapi.is often marks transit ISPs as datacenter. Require agreement.
bool consensusHosting(List<IpPuritySnapshot> parts) {
  bool? ipApiHosting;
  bool? ipapiDatacenter;
  var typeHosting = false;
  var typeResidential = false;
  for (final p in parts) {
    if (p.source == 'ip-api' && p.hosting != null) ipApiHosting = p.hosting;
    if (p.source == 'ipapi.is' && p.datacenter != null) ipapiDatacenter = p.datacenter;
    if (p.source == 'proxycheck') {
      final type = (p.networkType ?? '').toLowerCase();
      typeHosting = type == 'hosting' || type.contains('datacenter');
      typeResidential = const {'residential', 'wireless', 'education', 'government', 'business', 'corporate'}
          .contains(type);
      if (p.hosting == true) typeHosting = true;
    }
  }
  if (typeHosting) return true;
  if (ipApiHosting == true && ipapiDatacenter == true) return true;
  if (ipApiHosting == true && !typeResidential) return true;
  if (ipApiHosting == false) return false;
  if (ipapiDatacenter == true && !typeResidential) return true;
  return false;
}

bool? consensusNative({String? geoCountryCode, String? registryCountry}) {
  final geo = _normalizeCountryCode(geoCountryCode);
  final registry = _normalizeCountryCode(registryCountry);
  if (geo == null || registry == null) return null;
  return geo == registry;
}

IpPurityReport mergeIpPuritySnapshots(
  List<IpPuritySnapshot> parts, {
  required bool viaProxy,
  required DateTime testedAt,
}) {
  final usable = parts.where((p) => p.ip != null && p.ip!.trim().isNotEmpty).toList();
  if (usable.isEmpty) {
    throw const FormatException('no ip purity sources returned an address');
  }
  final counts = <String, int>{};
  for (final p in usable) {
    final ip = p.ip!.trim();
    counts[ip] = (counts[ip] ?? 0) + 1;
  }
  final ip = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final chosen = usable.where((p) => p.ip!.trim() == ip).toList();

  String pick(String? Function(IpPuritySnapshot p) read) {
    for (final p in chosen) {
      final v = read(p)?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  bool any(bool? Function(IpPuritySnapshot p) read) {
    for (final p in chosen) {
      if (read(p) == true) return true;
    }
    return false;
  }

  final hosting = consensusHosting(chosen);
  final proxy = any((p) => p.proxy);
  final vpn = any((p) => p.vpn);
  final tor = any((p) => p.tor);
  final abuser = any((p) => p.abuser);
  final mobile = any((p) => p.mobile);
  final countryCode = _emptyToNull(pick((p) => p.countryCode));
  final registryCountry = _emptyToNull(pick((p) => p.registryCountry));
  final networkType = _emptyToNull(pick((p) => p.networkType));
  final deviceCount = _firstInt(chosen.map((p) => p.deviceCount));
  final externalRisk = _firstInt(chosen.map((p) => p.externalRisk));
  final sources = <String>[];
  for (final p in chosen) {
    final name = p.source;
    if (name != null && !sources.contains(name)) sources.add(name);
  }
  return IpPurityReport(
    ip: ip,
    country: _emptyToNull(pick((p) => p.country)),
    countryCode: countryCode,
    region: _emptyToNull(pick((p) => p.region)),
    city: _emptyToNull(pick((p) => p.city)),
    isp: _emptyToNull(pick((p) => p.isp)),
    org: _emptyToNull(pick((p) => p.org)),
    asn: _emptyToNull(pick((p) => p.asn)),
    asnName: _emptyToNull(pick((p) => p.asnName)),
    lat: _firstNum(chosen.map((p) => p.lat)),
    lon: _firstNum(chosen.map((p) => p.lon)),
    registryCountry: registryCountry,
    networkType: networkType,
    deviceCount: deviceCount,
    externalRisk: externalRisk,
    native: consensusNative(geoCountryCode: countryCode, registryCountry: registryCountry),
    datacenter: hosting,
    hosting: hosting,
    proxy: proxy,
    vpn: vpn,
    tor: tor,
    abuser: abuser,
    mobile: mobile,
    score: computePurityScore(
      hosting: hosting,
      proxy: proxy,
      vpn: vpn,
      tor: tor,
      abuser: abuser,
      mobile: mobile,
      externalRisk: externalRisk ?? 0,
      deviceCount: deviceCount ?? 0,
    ),
    testedAt: testedAt,
    viaProxy: viaProxy,
    sources: sources,
  );
}

String? _str(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

double? _num(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _flag(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.toLowerCase();
    return s == 'true' || s == 'yes' || s == '1';
  }
  return false;
}

String? _emptyToNull(String value) => value.trim().isEmpty ? null : value;

double? _firstNum(Iterable<double?> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

int? _firstInt(Iterable<int?> values) {
  for (final value in values) {
    if (value != null) return value;
  }
  return null;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _normalizeCountryCode(String? raw) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.length == 2) return s.toUpperCase();
  const names = {
    'united states': 'US',
    'usa': 'US',
    'united kingdom': 'GB',
    'great britain': 'GB',
    'china': 'CN',
    'hong kong': 'HK',
    'taiwan': 'TW',
    'japan': 'JP',
    'korea': 'KR',
    'south korea': 'KR',
    'singapore': 'SG',
    'germany': 'DE',
    'france': 'FR',
    'netherlands': 'NL',
    'canada': 'CA',
    'australia': 'AU',
  };
  return names[s.toLowerCase()];
}
