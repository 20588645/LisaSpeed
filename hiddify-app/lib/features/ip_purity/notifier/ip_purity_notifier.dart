import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/ip_purity/data/ip_purity_client.dart';
import 'package:hiddify/features/ip_purity/model/ip_purity_report.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class IpPurityState {
  const IpPurityState({
    this.testing = false,
    this.report,
    this.failed = false,
  });

  final bool testing;
  final IpPurityReport? report;
  final bool failed;

  IpPurityState copyWith({
    bool? testing,
    IpPurityReport? report,
    bool? failed,
  }) {
    return IpPurityState(
      testing: testing ?? this.testing,
      report: report ?? this.report,
      failed: failed ?? this.failed,
    );
  }
}

final ipPurityProvider = NotifierProvider<IpPurityNotifier, IpPurityState>(IpPurityNotifier.new);

class IpPurityNotifier extends Notifier<IpPurityState> {
  static const _client = IpPurityClient();

  int _runId = 0;

  @override
  IpPurityState build() => const IpPurityState();

  Future<void> inspectIfIdle() async {
    if (state.testing || state.report != null || state.failed) return;
    await inspect();
  }

  Future<void> inspect() async {
    if (state.testing) return;
    final gen = ++_runId;
    state = IpPurityState(testing: true, report: state.report);
    try {
      final useProxy = ref.read(serviceRunningProvider);
      final mixedPort = ref.read(httpClientProvider).port;
      final fallbackPort = ref.read(ConfigOptions.mixedPort);
      final report = await _client.inspect(
        mixedPort: mixedPort > 0 ? mixedPort : fallbackPort,
        useProxy: useProxy,
      );
      if (gen != _runId) return;
      state = IpPurityState(report: report);
    } catch (_) {
      if (gen != _runId) return;
      state = IpPurityState(report: state.report, failed: true);
    }
  }
}
