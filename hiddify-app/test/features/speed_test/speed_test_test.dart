import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/speed_test/data/speed_test_targets.dart';
import 'package:hiddify/features/speed_test/data/speed_tester.dart';
import 'package:hiddify/features/speed_test/model/speed_test_math.dart';
import 'package:hiddify/features/speed_test/model/speed_test_report.dart';

void main() {
  test('1 MB in one second is 8 Mbps', () {
    expect(bytesToMbps(1000000, const Duration(seconds: 1)), 8);
  });

  test('zero bytes or duration is 0', () {
    expect(bytesToMbps(0, const Duration(seconds: 1)), 0);
    expect(bytesToMbps(1000, Duration.zero), 0);
  });

  test('median handles odd and even lists', () {
    expect(median([1, 3, 2]), 2);
    expect(median([1, 2, 3, 4]), 2.5);
    expect(medianInt([10, 30, 20]), 20);
  });

  test('75th percentile is interpolated', () {
    expect(percentile([10, 20, 30, 40], 0.75), 32.5);
    expect(percentile([8], 0.75), 8);
    expect(percentile([], 0.75), 0);
  });

  test('90th percentile is interpolated', () {
    expect(percentile([10, 20, 30, 40], 0.9), 37);
  });

  test('jitter is mean successive difference', () {
    expect(meanSuccessiveDiff([100, 110, 105]), 7.5);
    expect(meanSuccessiveDiff([50]), 0);
  });

  test('hung pings are dropped before jitter', () {
    expect(withoutPingOutliers([20, 22, 21, 2000]), [20, 22, 21]);
  });

  test('nearest speed-test target wins', () {
    expect(
      pickFastestTarget([(kCloudflareSpeedTarget, 406), (kTunaSpeedTarget, 18)]).id,
      'tuna',
    );
    expect(
      pickFastestTarget([(kCloudflareSpeedTarget, 80), (kTunaSpeedTarget, 60000)]).id,
      'cloudflare',
    );
  });

  test('direct tests keep a China mirror even when Cloudflare pings faster', () {
    expect(
      pickFastestTarget(
        [(kCloudflareSpeedTarget, 50), (kHuaweiSpeedTarget, 80)],
        preferDomestic: true,
      ).id,
      'huawei',
    );
  });

  test('warmup ping is dropped before idle median', () {
    expect(dropWarmupSample([800, 220, 224, 230]), [220, 224, 230]);
    expect(medianInt(dropWarmupSample([800, 220, 224, 230])), 224);
  });

  test('Mbps formatting matches professional two-decimal readout', () {
    expect(formatMbps(44.314), '44.31');
    expect(formatMbps(4.64), '4.64');
    expect(formatMbps(null), '—');
  });

  test('parse Cloudflare trace colo and loc', () {
    const body = '''
fl=123f9
h=speed.cloudflare.com
ip=192.220.58.72
colo=LAX
loc=US
http=http/2
tls=TLSv1.3
''';
    final trace = parseCloudflareTrace(body);
    expect(trace.ip, '192.220.58.72');
    expect(trace.colo, 'LAX');
    expect(trace.loc, 'US');
    expect(trace.city(chinese: true), '洛杉矶');
    expect(trace.city(chinese: false), 'Los Angeles');
    expect(cloudflareServerLabel(trace, chinese: true), 'Cloudflare · 洛杉矶 (LAX)');
    expect(speedTestServerLabel(serverId: 'tuna', chinese: true), '清华 TUNA 镜像');
    expect(speedTestServerLabel(serverId: 'tuna', chinese: false), 'Tsinghua TUNA');
    expect(speedTestServerLabel(serverId: 'huawei', chinese: true), '华为云镜像');
  });

  test('classifySpeedTestError maps timeout tls network cancel', () {
    expect(classifySpeedTestError(TimeoutException('x')), SpeedTestFailureKind.timeout);
    expect(
      classifySpeedTestError(const SocketException('Connection refused')),
      SpeedTestFailureKind.network,
    );
    expect(
      classifySpeedTestError(HandshakeException('handshake failed')),
      SpeedTestFailureKind.tls,
    );
    expect(classifySpeedTestError(const SpeedTestCancelled()), SpeedTestFailureKind.cancelled);
  });
}
