import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/ip_purity/model/ip_purity_report.dart';

void main() {
  test('clean residential IP scores excellent', () {
    expect(
      computePurityScore(
        hosting: false,
        proxy: false,
        vpn: false,
        tor: false,
        abuser: false,
        mobile: false,
      ),
      88,
    );
    expect(gradeForScore(88), IpPurityGrade.excellent);
  });

  test('consensus hosting plus proxy raises risk', () {
    expect(
      computePurityScore(
        hosting: true,
        proxy: true,
        vpn: false,
        tor: false,
        abuser: false,
        mobile: false,
      ),
      38,
    );
    expect(gradeForScore(38), IpPurityGrade.poor);
  });

  test('tor plus abuse is treated as high risk', () {
    final score = computePurityScore(
      hosting: false,
      proxy: false,
      vpn: false,
      tor: true,
      abuser: true,
      mobile: false,
    );
    expect(score, 34);
    expect(gradeForScore(score), IpPurityGrade.poor);
  });

  test('scene verdicts follow score and flags', () {
    expect(
      sceneVerdict(kind: IpSceneKind.tiktok, score: 88, proxyLike: false, hosting: false, abuser: false),
      IpSceneVerdict.perfect,
    );
    expect(
      sceneVerdict(kind: IpSceneKind.commerce, score: 62, proxyLike: false, hosting: false, abuser: false),
      IpSceneVerdict.tryable,
    );
    expect(
      sceneVerdict(kind: IpSceneKind.social, score: 88, proxyLike: true, hosting: true, abuser: false),
      IpSceneVerdict.avoid,
    );
    expect(
      sceneVerdict(kind: IpSceneKind.ai, score: 58, proxyLike: true, hosting: true, abuser: false),
      IpSceneVerdict.perfect,
    );
    expect(
      sceneVerdict(kind: IpSceneKind.ai, score: 80, proxyLike: false, hosting: false, abuser: true),
      IpSceneVerdict.avoid,
    );
  });

  test('NTT transit IP is not hosting when ip-api and proxycheck disagree with ipapi.is', () {
    final who = parseIpWhoIs({
      'success': true,
      'ip': '192.220.58.72',
      'country': 'United States',
      'country_code': 'US',
      'region': 'California',
      'city': 'Los Angeles',
      'latitude': 34.0544,
      'longitude': -118.244,
      'connection': {'asn': 2914, 'org': 'NTT America, Inc.', 'isp': 'NTT Communications'},
    });
    final api = parseIpApi({
      'status': 'success',
      'query': '192.220.58.72',
      'country': 'United States',
      'countryCode': 'US',
      'regionName': 'California',
      'city': 'Los Angeles',
      'lat': 34.0522,
      'lon': -118.2437,
      'isp': 'NTT Communications',
      'org': 'NTT America',
      'as': 'AS2914 NTT America, Inc.',
      'asname': 'NTT-DATA-2914',
      'mobile': false,
      'proxy': false,
      'hosting': false,
    });
    final apiIs = parseIpApiIs({
      'ip': '192.220.58.72',
      'is_datacenter': true,
      'is_proxy': false,
      'is_vpn': false,
      'is_tor': false,
      'is_abuser': false,
      'company_name': 'NTT America, Inc.',
      'asn_num': 2914,
      'asn_org': 'NTT America, Inc.',
      'cc': 'US',
    });
    final check = parseProxyCheck({
      'status': 'ok',
      '192.220.58.72': {
        'asn': 'AS2914',
        'provider': 'NTT America, Inc.',
        'organisation': 'NTT Communications',
        'country': 'United States',
        'isocode': 'US',
        'region': 'California',
        'city': 'Los Angeles',
        'latitude': 34.0549,
        'longitude': -118.243,
        'devices': {'address': 0, 'subnet': 0},
        'proxy': 'no',
        'type': 'Business',
        'risk': 0,
      },
    });
    final ripe = parseRipeWhois({
      'data': {
        'resource': '192.220.58.72',
        'records': [
          [
            {'key': 'OrgName', 'value': 'NTT America, Inc.'},
            {'key': 'Country', 'value': 'US'},
          ],
        ],
      },
    });

    expect(apiIs?.datacenter, isTrue);
    expect(apiIs?.hosting, isNot(true));
    expect(check?.networkType, 'Business');
    expect(ripe?.registryCountry, 'US');

    final merged = mergeIpPuritySnapshots(
      [who!, api!, apiIs!, check!, ripe!],
      viaProxy: true,
      testedAt: DateTime(2026, 8, 15, 23, 36, 57),
    );
    expect(merged.ip, '192.220.58.72');
    expect(merged.hosting, isFalse);
    expect(merged.native, isTrue);
    expect(merged.lineType, IpLineType.business);
    expect(merged.deviceCount, 0);
    expect(merged.score, 88);
    expect(merged.grade, IpPurityGrade.excellent);
    expect(merged.verdictFor(IpSceneKind.tiktok), IpSceneVerdict.tryable);
    expect(merged.verdictFor(IpSceneKind.ai), IpSceneVerdict.perfect);
    expect(merged.sources, ['ipwho.is', 'ip-api', 'ipapi.is', 'proxycheck', 'ripe']);
  });

  test('Google DNS is hosting when ip-api and ipapi.is agree', () {
    final api = parseIpApi({
      'status': 'success',
      'query': '8.8.8.8',
      'country': 'United States',
      'countryCode': 'US',
      'isp': 'Google LLC',
      'org': 'Google Public DNS',
      'as': 'AS15169 Google LLC',
      'proxy': false,
      'hosting': true,
    });
    final apiIs = parseIpApiIs({
      'ip': '8.8.8.8',
      'is_datacenter': true,
      'is_proxy': false,
      'company': {'name': 'Google LLC', 'type': 'hosting'},
      'asn': {'asn': 15169, 'org': 'Google LLC'},
      'location': {'country_code': 'US'},
    });
    final check = parseProxyCheck({
      'status': 'ok',
      '8.8.8.8': {
        'provider': 'Google LLC',
        'isocode': 'US',
        'proxy': 'no',
        'type': 'Business',
        'risk': 0,
        'devices': {'address': 0},
      },
    });
    final merged = mergeIpPuritySnapshots(
      [api!, apiIs!, check!],
      viaProxy: false,
      testedAt: DateTime(2026, 8, 16),
    );
    expect(merged.hosting, isTrue);
    expect(merged.lineType, IpLineType.hosting);
    expect(merged.score, 62);
  });

  test('native IP follows registry country vs geo country', () {
    expect(consensusNative(geoCountryCode: 'US', registryCountry: 'US'), isTrue);
    expect(consensusNative(geoCountryCode: 'US', registryCountry: 'HK'), isFalse);
    expect(consensusNative(geoCountryCode: 'US', registryCountry: null), isNull);
  });

  test('compact ipapi.is payload still parses flags without forcing hosting', () {
    final snap = parseIpApiIs({
      'ip': '45.43.70.41',
      'is_datacenter': true,
      'is_tor': false,
      'is_proxy': true,
      'is_vpn': false,
      'is_abuser': true,
      'company_name': 'SYN LTD',
      'asn_num': 64080,
      'asn_org': 'SYN LTD',
      'cc': 'GB',
      'lat': 51.50853,
      'lon': -0.12574,
    });
    expect(snap?.asn, 'AS64080');
    expect(snap?.countryCode, 'GB');
    expect(snap?.proxy, isTrue);
    expect(snap?.abuser, isTrue);
    expect(snap?.datacenter, isTrue);
    expect(snap?.hosting, isNot(true));
  });

  test('merge throws when every source is empty', () {
    expect(
      () => mergeIpPuritySnapshots(const [], viaProxy: false, testedAt: DateTime(2026, 8, 15)),
      throwsFormatException,
    );
  });
}
