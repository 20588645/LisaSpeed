import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/link_test/data/link_test_catalog.dart';
import 'package:hiddify/features/link_test/data/link_tester.dart';
import 'package:hiddify/features/link_test/model/link_test_target.dart';
import 'package:hiddify/features/link_test/model/probe_grade.dart';

void main() {
  test('catalog has both domestic and overseas sites', () {
    expect(kLinkTestCatalog.where((t) => t.group == LinkTestGroup.cn), isNotEmpty);
    expect(kLinkTestCatalog.where((t) => t.group == LinkTestGroup.intl), isNotEmpty);
    expect(kLinkTestCatalog.map((t) => t.id).toSet().length, kLinkTestCatalog.length);
    expect(kLinkTestCatalog.every((t) => t.url.startsWith('https://')), isTrue);
  });

  test('classifyLinkTestError maps timeout, tls, and network', () {
    expect(classifyLinkTestError(TimeoutException('x')), LinkTestFailureKind.timeout);
    expect(
      classifyLinkTestError(const SocketException('Connection timed out')),
      LinkTestFailureKind.timeout,
    );
    expect(
      classifyLinkTestError(const SocketException('Connection refused')),
      LinkTestFailureKind.network,
    );
    expect(
      classifyLinkTestError(HandshakeException('handshake failed')),
      LinkTestFailureKind.tls,
    );
  });

  test('domestic probes stay direct while overseas use the node when connected', () {
    expect(linkTestUsesProxy(LinkTestGroup.cn, true), isFalse);
    expect(linkTestUsesProxy(LinkTestGroup.cn, false), isFalse);
    expect(linkTestUsesProxy(LinkTestGroup.intl, true), isTrue);
    expect(linkTestUsesProxy(LinkTestGroup.intl, false), isFalse);
  });

  test('target host is parsed from url', () {
    const t = LinkTestTarget(
      id: 'g',
      nameZh: 'Google',
      nameEn: 'Google',
      url: 'https://www.google.com/path',
      group: LinkTestGroup.intl,
    );
    expect(t.host, 'www.google.com');
    expect(t.displayName(chinese: true), 'Google');
  });

  test('homepage probe latency is graded, not treated as a usable page', () {
    expect(gradeLatencyMs(0), ProbeGrade.ok);
    expect(gradeLatencyMs(399), ProbeGrade.ok);
    expect(gradeLatencyMs(400), ProbeGrade.sluggish);
    expect(gradeLatencyMs(999), ProbeGrade.sluggish);
    expect(gradeLatencyMs(1000), ProbeGrade.switchNode);
    expect(gradeLatencyMs(1064), ProbeGrade.switchNode);
  });
}
