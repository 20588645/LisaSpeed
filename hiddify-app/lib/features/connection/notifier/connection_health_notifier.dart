import 'dart:async';

import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/notification/native_notifier.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_health_notifier.g.dart';

enum ConnectionHealth { unknown, healthy, stalled }

/// Connection watchdog. While connected it periodically checks that data
/// actually flows through the tunnel — not just that the TCP/TLS handshake
/// succeeded — by fetching a tiny test URL *through the proxy*. This catches
/// the "connected but blackholed" failure (e.g. an office firewall that lets
/// the handshake through then drops the payload), which otherwise looks
/// perfectly connected. On a sustained stall it alerts the user and, when
/// enabled, reconnects to self-heal.
@Riverpod(keepAlive: true)
class ConnectionHealthNotifier extends _$ConnectionHealthNotifier with AppLogger {
  Timer? _timer;
  int _fails = 0;
  bool _probing = false;
  DateTime? _lastAutoReconnect;

  static const _interval = Duration(seconds: 30);
  static const _failThreshold = 2;
  static const _probeTimeout = Duration(seconds: 8);
  static const _reconnectCooldown = Duration(minutes: 3);
  static const _fallbackTestUrl = 'https://www.gstatic.com/generate_204';

  @override
  ConnectionHealth build() {
    final running = ref.watch(serviceRunningProvider);
    _timer?.cancel();
    _timer = null;
    _fails = 0;
    ref.onDispose(() => _timer?.cancel());
    if (!running) return ConnectionHealth.unknown;
    _timer = Timer.periodic(_interval, (_) => unawaited(_probe()));
    // Give the freshly-built tunnel a moment before the first probe.
    Future.delayed(const Duration(seconds: 6), () => unawaited(_probe()));
    return ConnectionHealth.healthy;
  }

  /// One-shot reachability check (also used by the manual connectivity test).
  Future<bool> checkNow() => _reachable();

  Future<void> _probe() async {
    if (_probing || !ref.read(serviceRunningProvider)) return;
    _probing = true;
    try {
      if (await _reachable()) {
        _fails = 0;
        if (state == ConnectionHealth.stalled) {
          _notifyRecovered();
        }
        state = ConnectionHealth.healthy;
        return;
      }
      _fails++;
      loggy.warning('connectivity probe failed ($_fails/$_failThreshold)');
      if (_fails >= _failThreshold && state != ConnectionHealth.stalled) {
        state = ConnectionHealth.stalled;
        await _onStalled();
      }
    } finally {
      _probing = false;
    }
  }

  Future<bool> _reachable() async {
    final configured = ref.read(ConfigOptions.connectionTestUrl);
    final url = configured.isNotEmpty ? configured : _fallbackTestUrl;
    try {
      final res = await ref.read(httpClientProvider).get(url, proxyOnly: true).timeout(_probeTimeout);
      final code = res.statusCode ?? 0;
      return code >= 200 && code < 400;
    } catch (e) {
      loggy.debug('probe error: $e');
      return false;
    }
  }

  Future<void> _onStalled() async {
    final t = ref.read(translationsProvider).requireValue;
    final now = DateTime.now();
    final canReconnect = ref.read(Preferences.autoReconnectOnStall) &&
        (_lastAutoReconnect == null || now.difference(_lastAutoReconnect!) > _reconnectCooldown);
    final body = canReconnect ? t.connection.watchdog.stalledBody : t.connection.watchdog.stalledBodyManual;

    ref.read(inAppNotificationControllerProvider).showErrorToast(body);
    await NativeNotifier.show(t.connection.watchdog.stalledTitle, body);

    if (canReconnect) {
      _lastAutoReconnect = now;
      loggy.info('watchdog auto-reconnecting after stall');
      try {
        final profile = await ref.read(activeProfileProvider.future);
        await ref.read(connectionNotifierProvider.notifier).reconnect(profile);
      } catch (e) {
        loggy.warning('watchdog reconnect failed: $e');
      }
    }
  }

  void _notifyRecovered() {
    final t = ref.read(translationsProvider).requireValue;
    ref.read(inAppNotificationControllerProvider).showSuccessToast(t.connection.watchdog.recovered);
  }
}
