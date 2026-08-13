import 'dart:async';

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

  Timer? _timer;

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
    } catch (e) {
      loggy.warning('host panel quota refresh failed: $e');
    }
  }
}
