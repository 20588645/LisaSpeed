import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/link_test/notifier/link_test_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/speed_test/data/speed_tester.dart';
import 'package:hiddify/features/speed_test/model/speed_test_math.dart';
import 'package:hiddify/features/speed_test/model/speed_test_report.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpeedTestState {
  const SpeedTestState({
    this.running = false,
    this.phase = SpeedTestPhase.idle,
    this.fraction = 0,
    this.downloadMbps,
    this.uploadMbps,
    this.idlePingMs,
    this.downloadLoadedPingMs,
    this.uploadLoadedPingMs,
    this.jitterMs,
    this.trace,
    this.serverId,
    this.viaProxy,
    this.testedAt,
    this.failure,
    this.uploadFailed = false,
  });

  final bool running;
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
  final bool? viaProxy;
  final DateTime? testedAt;
  final SpeedTestFailureKind? failure;
  final bool uploadFailed;

  bool get hasResult => testedAt != null || idlePingMs != null || downloadMbps != null;

  SpeedTestState copyWith({
    bool? running,
    SpeedTestPhase? phase,
    double? fraction,
    double? downloadMbps,
    double? uploadMbps,
    int? idlePingMs,
    int? downloadLoadedPingMs,
    int? uploadLoadedPingMs,
    double? jitterMs,
    CloudflareTrace? trace,
    String? serverId,
    bool? viaProxy,
    DateTime? testedAt,
    SpeedTestFailureKind? failure,
    bool? uploadFailed,
    bool clearFailure = false,
  }) {
    return SpeedTestState(
      running: running ?? this.running,
      phase: phase ?? this.phase,
      fraction: fraction ?? this.fraction,
      downloadMbps: downloadMbps ?? this.downloadMbps,
      uploadMbps: uploadMbps ?? this.uploadMbps,
      idlePingMs: idlePingMs ?? this.idlePingMs,
      downloadLoadedPingMs: downloadLoadedPingMs ?? this.downloadLoadedPingMs,
      uploadLoadedPingMs: uploadLoadedPingMs ?? this.uploadLoadedPingMs,
      jitterMs: jitterMs ?? this.jitterMs,
      trace: trace ?? this.trace,
      serverId: serverId ?? this.serverId,
      viaProxy: viaProxy ?? this.viaProxy,
      testedAt: testedAt ?? this.testedAt,
      failure: clearFailure ? null : (failure ?? this.failure),
      uploadFailed: uploadFailed ?? this.uploadFailed,
    );
  }

  SpeedTestState applyProgress(SpeedTestProgress progress) {
    return copyWith(
      running: true,
      phase: progress.phase,
      fraction: progress.fraction,
      downloadMbps: progress.downloadMbps,
      uploadMbps: progress.uploadMbps,
      idlePingMs: progress.idlePingMs,
      downloadLoadedPingMs: progress.downloadLoadedPingMs,
      uploadLoadedPingMs: progress.uploadLoadedPingMs,
      jitterMs: progress.jitterMs,
      trace: progress.trace,
      serverId: progress.serverId,
      viaProxy: progress.viaProxy,
      uploadFailed: progress.uploadFailed,
      clearFailure: true,
    );
  }
}

final speedTestProvider = NotifierProvider<SpeedTestNotifier, SpeedTestState>(SpeedTestNotifier.new);

class SpeedTestNotifier extends Notifier<SpeedTestState> {
  SpeedTester? _active;
  int _runId = 0;

  @override
  SpeedTestState build() {
    ref.onDispose(() {
      _runId++;
      _active?.cancel();
      _active = null;
    });
    return const SpeedTestState();
  }

  Future<void> toggle() async {
    if (state.running) {
      cancel();
      return;
    }
    await start();
  }

  Future<void> start() async {
    if (state.running) return;
    if (ref.read(linkTestProvider).testingIds.isNotEmpty) return;

    final gen = ++_runId;
    final tester = SpeedTester();
    _active = tester;
    final useProxy = ref.read(serviceRunningProvider);
    final mixedPort = ref.read(httpClientProvider).port;
    final fallbackPort = ref.read(ConfigOptions.mixedPort);
    state = SpeedTestState(running: true, phase: SpeedTestPhase.ping, viaProxy: useProxy);
    await ref.read(hapticServiceProvider.notifier).lightImpact();

    try {
      final report = await tester.run(
        mixedPort: mixedPort > 0 ? mixedPort : fallbackPort,
        useProxy: useProxy,
        onProgress: (progress) {
          if (gen != _runId) return;
          state = state.applyProgress(progress);
        },
      );
      if (gen != _runId) return;
      state = SpeedTestState(
        phase: SpeedTestPhase.done,
        fraction: 1,
        downloadMbps: report.downloadMbps,
        uploadMbps: report.uploadMbps,
        idlePingMs: report.idlePingMs,
        downloadLoadedPingMs: report.downloadLoadedPingMs,
        uploadLoadedPingMs: report.uploadLoadedPingMs,
        jitterMs: report.jitterMs,
        trace: report.trace,
        serverId: report.serverId,
        viaProxy: report.viaProxy,
        testedAt: report.testedAt,
        uploadFailed: report.uploadFailed,
      );
    } on SpeedTestCancelled {
      if (gen != _runId) return;
      state = state.copyWith(
        running: false,
        phase: SpeedTestPhase.cancelled,
        testedAt: state.testedAt ?? DateTime.now(),
      );
    } catch (err) {
      if (gen != _runId) return;
      if ((state.downloadMbps ?? 0) > 0) {
        state = state.copyWith(
          running: false,
          phase: SpeedTestPhase.done,
          uploadFailed: true,
          testedAt: state.testedAt ?? DateTime.now(),
          clearFailure: true,
        );
        return;
      }
      state = state.copyWith(
        running: false,
        phase: SpeedTestPhase.failed,
        failure: classifySpeedTestError(err),
        testedAt: state.testedAt ?? DateTime.now(),
      );
    } finally {
      if (identical(_active, tester)) _active = null;
    }
  }

  void cancel() {
    _runId++;
    _active?.cancel();
    _active = null;
    if (!state.running) return;
    state = state.copyWith(
      running: false,
      phase: SpeedTestPhase.cancelled,
      testedAt: state.testedAt ?? DateTime.now(),
    );
  }
}
