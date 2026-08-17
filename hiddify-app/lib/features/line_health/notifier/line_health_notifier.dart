import 'dart:async';

import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/notification/native_notifier.dart';
import 'package:hiddify/features/connection/notifier/connection_health_notifier.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/line_health/model/line_health_verdict.dart';
import 'package:hiddify/features/link_test/data/link_test_catalog.dart';
import 'package:hiddify/features/link_test/data/link_tester.dart';
import 'package:hiddify/features/link_test/model/link_test_target.dart';
import 'package:hiddify/features/link_test/notifier/link_test_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/speed_test/notifier/speed_test_notifier.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LineHealthState {
  const LineHealthState({
    this.running = false,
    this.verdict,
    this.snapshot,
    this.testedAt,
  });

  final bool running;
  final LineHealthVerdict? verdict;
  final LineHealthSnapshot? snapshot;
  final DateTime? testedAt;

  LineHealthState copyWith({
    bool? running,
    LineHealthVerdict? verdict,
    LineHealthSnapshot? snapshot,
    DateTime? testedAt,
  }) {
    return LineHealthState(
      running: running ?? this.running,
      verdict: verdict ?? this.verdict,
      snapshot: snapshot ?? this.snapshot,
      testedAt: testedAt ?? this.testedAt,
    );
  }
}

final lineHealthProvider = NotifierProvider<LineHealthNotifier, LineHealthState>(LineHealthNotifier.new);

class LineHealthNotifier extends Notifier<LineHealthState> with AppLogger {
  static const _tester = LinkTester();
  static const _timeout = Duration(seconds: 6);

  @override
  LineHealthState build() => const LineHealthState();

  Future<void> run() async {
    if (state.running) return;
    if (ref.read(speedTestProvider).running) return;
    if (ref.read(linkTestProvider).testingIds.isNotEmpty) return;

    state = state.copyWith(running: true);
    try {
      final connected = ref.read(serviceRunningProvider);
      if (!connected) {
        const snapshot = LineHealthSnapshot(
          connected: false,
          tunnelOk: false,
          cnOk: false,
          intlOk: false,
        );
        _finish(snapshot);
        return;
      }

      final mixedPort = ref.read(httpClientProvider).port;
      final fallbackPort = ref.read(ConfigOptions.mixedPort);
      final port = mixedPort > 0 ? mixedPort : fallbackPort;

      final cnTargets = kLinkTestCatalog.where((t) => t.group == LinkTestGroup.cn).take(2).toList();
      final intlTargets = kLinkTestCatalog.where((t) => t.group == LinkTestGroup.intl).take(2).toList();

      final tunnelFuture = ref.read(connectionHealthNotifierProvider.notifier).checkNow();
      final cnFuture = _anyOk(cnTargets, mixedPort: port, useProxy: false);
      final intlFuture = _bestOk(intlTargets, mixedPort: port, useProxy: true);

      final tunnelOk = await tunnelFuture;
      final cnOk = await cnFuture;
      final intl = await intlFuture;

      _finish(
        LineHealthSnapshot(
          connected: true,
          tunnelOk: tunnelOk,
          cnOk: cnOk,
          intlOk: intl.$1,
          intlLatencyMs: intl.$2,
        ),
      );
    } catch (e) {
      loggy.warning('line health failed: $e');
      state = state.copyWith(running: false);
    }
  }

  Future<bool> _anyOk(
    List<LinkTestTarget> targets, {
    required int mixedPort,
    required bool useProxy,
  }) async {
    final best = await _bestOk(targets, mixedPort: mixedPort, useProxy: useProxy);
    return best.$1;
  }

  Future<(bool, int?)> _bestOk(
    List<LinkTestTarget> targets, {
    required int mixedPort,
    required bool useProxy,
  }) async {
    for (final target in targets) {
      final outcome = await _tester.probe(
        target: target,
        mixedPort: mixedPort,
        useProxy: useProxy,
        timeout: _timeout,
      );
      if (outcome.ok) return (true, outcome.latencyMs);
    }
    return (false, null);
  }

  void _finish(LineHealthSnapshot snapshot) {
    final verdict = concludeLineHealth(snapshot);
    state = LineHealthState(
      verdict: verdict,
      snapshot: snapshot,
      testedAt: DateTime.now(),
    );
    final t = ref.read(translationsProvider).requireValue;
    final body = lineHealthVerdictText(t, verdict);
    if (verdict == LineHealthVerdict.ok) {
      ref.read(inAppNotificationControllerProvider).showSuccessToast(body);
    } else if (verdict == LineHealthVerdict.notConnected || verdict == LineHealthVerdict.sluggish) {
      ref.read(inAppNotificationControllerProvider).showInfoToast(body, duration: const Duration(seconds: 5));
    } else {
      ref.read(inAppNotificationControllerProvider).showErrorToast(body);
    }
    unawaited(NativeNotifier.show(t.pages.lineHealth.title, body));
  }
}

String lineHealthVerdictText(Translations t, LineHealthVerdict verdict) => switch (verdict) {
  LineHealthVerdict.notConnected => t.pages.lineHealth.verdictNotConnected,
  LineHealthVerdict.ok => t.pages.lineHealth.verdictOk,
  LineHealthVerdict.sluggish => t.pages.lineHealth.verdictSluggish,
  LineHealthVerdict.switchNode => t.pages.lineHealth.verdictSwitchNode,
  LineHealthVerdict.nodeDead => t.pages.lineHealth.verdictNodeDead,
  LineHealthVerdict.intlFail => t.pages.lineHealth.verdictIntlFail,
  LineHealthVerdict.localFail => t.pages.lineHealth.verdictLocalFail,
  LineHealthVerdict.mixed => t.pages.lineHealth.verdictMixed,
};
