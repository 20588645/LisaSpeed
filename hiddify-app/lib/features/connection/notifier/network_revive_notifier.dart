import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// macOS sleep/wake and path changes from `MainFlutterWindow.swift`.
class MacosLifecycleEvents {
  MacosLifecycleEvents._();

  static const _channel = EventChannel('com.lisaspeed/lifecycle');

  static Stream<String> events() {
    if (!Platform.isMacOS) return const Stream.empty();
    return _channel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return event['type']?.toString() ?? '';
      }
      return event?.toString() ?? '';
    }).where((type) => type == 'wake' || type == 'network');
  }
}

/// Reconnects the tunnel after laptop sleep or switching Wi-Fi / hotspot, when
/// the user had asked LisaSpeed to stay connected.
final networkReviveProvider = NotifierProvider<NetworkReviveNotifier, int>(NetworkReviveNotifier.new);

class NetworkReviveNotifier extends Notifier<int> with AppLogger {
  StreamSubscription<String>? _sub;
  Timer? _debounce;
  DateTime? _lastRevive;

  static const _wakeDelay = Duration(seconds: 4);
  static const _networkDelay = Duration(seconds: 2);
  static const _cooldown = Duration(seconds: 20);

  @override
  int build() {
    _sub?.cancel();
    _debounce?.cancel();
    if (!PlatformUtils.isMacOS) return 0;
    _sub = MacosLifecycleEvents.events().listen(_onEvent);
    ref.onDispose(() {
      _debounce?.cancel();
      unawaited(_sub?.cancel());
    });
    return 0;
  }

  void _onEvent(String type) {
    _debounce?.cancel();
    final delay = type == 'wake' ? _wakeDelay : _networkDelay;
    _debounce = Timer(delay, () => unawaited(_revive(type)));
  }

  Future<void> _revive(String type) async {
    final now = DateTime.now();
    if (_lastRevive != null && now.difference(_lastRevive!) < _cooldown) return;
    if (!ref.read(Preferences.startedByUser)) return;
    if (!ref.read(Preferences.autoReconnectOnStall)) return;
    _lastRevive = now;
    loggy.info('reviving tunnel after $type');
    final t = ref.read(translationsProvider).requireValue;
    ref.read(inAppNotificationControllerProvider).showInfoToast(t.connection.watchdog.reviving);
    await ref.read(connectionNotifierProvider.notifier).reviveAfterInterrupt(reason: type);
  }
}
