import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/ip_purity/model/ip_purity_report.dart';

const _kBrowserUa =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

const _kIpWhoIs = 'https://ipwho.is/';
const _kIpApi =
    'http://ip-api.com/json/?fields=status,country,countryCode,regionName,city,lat,lon,isp,org,as,asname,mobile,proxy,hosting,query';
const _kIpApiIs = 'https://api.ipapi.is/';
const _kProxyCheck = 'https://proxycheck.io/v2/?vpn=1&asn=1&risk=1';

class IpPurityClient {
  const IpPurityClient();

  Future<IpPurityReport> inspect({
    required int mixedPort,
    required bool useProxy,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = HttpClient();
    client.userAgent = _kBrowserUa;
    client.connectionTimeout = timeout;
    client.idleTimeout = timeout;
    if (useProxy && mixedPort > 0) {
      client.findProxy = (_) => 'PROXY 127.0.0.1:$mixedPort';
    } else {
      client.findProxy = (_) => 'DIRECT';
    }

    try {
      final raw = await Future.wait([
        _getJson(client, Uri.parse(_kIpWhoIs), timeout),
        _getJson(client, Uri.parse(_kIpApi), timeout),
        _getJson(client, Uri.parse(_kIpApiIs), timeout),
        _getJson(client, Uri.parse(_kProxyCheck), timeout),
      ]);
      final parts = <IpPuritySnapshot>[];
      final who = raw[0] == null ? null : parseIpWhoIs(raw[0]!);
      final api = raw[1] == null ? null : parseIpApi(raw[1]!);
      final apiIs = raw[2] == null ? null : parseIpApiIs(raw[2]!);
      final check = raw[3] == null ? null : parseProxyCheck(raw[3]!);
      if (who != null) parts.add(who);
      if (api != null) parts.add(api);
      if (apiIs != null) parts.add(apiIs);
      if (check != null) parts.add(check);

      final testedAt = DateTime.now();
      var report = mergeIpPuritySnapshots(parts, viaProxy: useProxy, testedAt: testedAt);
      final ripeUri = Uri.parse(
        'https://stat.ripe.net/data/whois/data.json?resource=${Uri.encodeComponent(report.ip)}',
      );
      final ripeJson = await _getJson(client, ripeUri, timeout);
      final ripe = ripeJson == null ? null : parseRipeWhois(ripeJson, fallbackIp: report.ip);
      if (ripe != null) {
        parts.add(ripe);
        report = mergeIpPuritySnapshots(parts, viaProxy: useProxy, testedAt: testedAt);
      }
      return report;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>?> _getJson(HttpClient client, Uri uri, Duration timeout) async {
    try {
      final req = await client.getUrl(uri).timeout(timeout);
      req.followRedirects = true;
      req.maxRedirects = 5;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/plain, */*');
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }
}
