import 'package:hiddify/features/speed_test/model/speed_test_math.dart';

enum SpeedTestPhase { idle, ping, download, upload, done, failed, cancelled }

enum SpeedTestFailureKind { timeout, network, tls, cancelled, unknown }

class SpeedTestCancelled implements Exception {
  const SpeedTestCancelled();

  @override
  String toString() => 'SpeedTestCancelled';
}

class SpeedTestException implements Exception {
  const SpeedTestException(this.kind, [this.message]);

  final SpeedTestFailureKind kind;
  final String? message;

  @override
  String toString() => 'SpeedTestException($kind${message == null ? '' : ': $message'})';
}

class SpeedTestProgress {
  const SpeedTestProgress({
    required this.phase,
    this.fraction = 0,
    this.downloadMbps,
    this.uploadMbps,
    this.idlePingMs,
    this.downloadLoadedPingMs,
    this.uploadLoadedPingMs,
    this.jitterMs,
    this.trace,
    this.serverId,
    this.viaProxy = false,
    this.uploadFailed = false,
  });

  final SpeedTestPhase phase;
  final double fraction;
  final double? downloadMbps;
  final double? uploadMbps;
  final int? idlePingMs;
  final int? downloadLoadedPingMs;
  final int? uploadLoadedPingMs;
  final double? jitterMs;
  final CloudflareTrace? trace;
  final String? serverId;
  final bool viaProxy;
  final bool uploadFailed;
}

class SpeedTestReport {
  const SpeedTestReport({
    required this.testedAt,
    required this.viaProxy,
    required this.downloadMbps,
    required this.uploadMbps,
    required this.idlePingMs,
    this.downloadLoadedPingMs,
    this.uploadLoadedPingMs,
    required this.jitterMs,
    this.trace,
    this.serverId,
    this.uploadFailed = false,
  });

  final DateTime testedAt;
  final bool viaProxy;
  final double downloadMbps;
  final double uploadMbps;
  final int idlePingMs;
  final int? downloadLoadedPingMs;
  final int? uploadLoadedPingMs;
  final double jitterMs;
  final CloudflareTrace? trace;
  final String? serverId;
  final bool uploadFailed;
}
