import 'dart:async';

import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/notification/native_notifier.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/host_panel/data/lisahost_client.dart';
import 'package:hiddify/features/host_panel/model/host_quota.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Polls the LisaHost panel for the VPS traffic quota every ten minutes
/// while enabled and configured; null when the feature is off. The last
/// snapshot is persisted so the home card paints immediately on launch.
final hostQuotaProvider = NotifierProvider<HostQuotaNotifier, HostQuota?>(HostQuotaNotifier.new);

class HostQuotaNotifier extends Notifier<HostQuota?> with AppLogger {
  static const _snapshotKey = 'host_panel_quota_snapshot';
  static const _interval = Duration(minutes: 10);
  static const _alertThreshold = 0.9;

  Timer? _timer;

  /// One-shot latch so the near-quota alert fires once per billing cycle; it
  /// re-arms automatically when usage drops below the threshold (i.e. after
  /// the monthly reset).
  bool _alerted = false;

  @override
  HostQuota? build() {
    final enabled = ref.watch(Preferences.hostPanelEnabled);
    final email = ref.watch(Preferences.hostPanelEmail);
    final password = ref.watch(Preferences.hostPanelPassword);

    _timer?.cancel();
    _timer = null;
    if (!enabled || email.isEmpty || password.isEmpty) return null;

    final client = LisahostClient(email: email, password: password);
    _timer = Timer.periodic(_interval, (_) => _refresh(client));
    ref.onDispose(() => _timer?.cancel());
    scheduleMicrotask(() => _refresh(client));

    final raw = ref.read(sharedPreferencesProvider).requireValue.getString(_snapshotKey);
    return raw == null ? null : HostQuota.fromJsonString(raw);
  }

  Future<void> _refresh(LisahostClient client) async {
    try {
      final quota = await client.fetchQuota();
      state = quota;
      await ref.read(sharedPreferencesProvider).requireValue.setString(_snapshotKey, quota.toJsonString());
      _maybeAlert(quota);
    } catch (e) {
      loggy.warning('host panel quota refresh failed: $e');
    }
  }

  void _maybeAlert(HostQuota quota) {
    if (quota.totalGb <= 0) return;
    if (quota.ratio < _alertThreshold) {
      _alerted = false;
      return;
    }
    if (_alerted) return;
    _alerted = true;
    final t = ref.read(translationsProvider).requireValue;
    final body = t.alerts.quotaBody(
      used: quota.usedGb.toStringAsFixed(0),
      total: quota.totalGb.toStringAsFixed(0),
      percent: (quota.ratio * 100).round(),
    );
    ref.read(inAppNotificationControllerProvider).showInfoToast(body, duration: const Duration(seconds: 6));
    NativeNotifier.show(t.alerts.quotaTitle, body);
  }
}
