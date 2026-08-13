import 'dart:async';

import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';

/// Mirrors the live up/down rates beside the macOS menu-bar icon as a
/// two-line 9pt readout (vendored tray_manager setTitleLines). Cleared
/// while disconnected or when the preference is off.
final traySpeedNotifierProvider = Provider<void>((ref) {
  if (!PlatformUtils.isMacOS) return;
  final enabled = ref.watch(Preferences.showTraySpeed);
  final running = ref.watch(serviceRunningProvider);
  if (!enabled || !running) {
    _push('', '');
    return;
  }
  final stats = ref.watch(statsNotifierProvider).asData?.value;
  _push(
    '↑ ${_formatSpeed(stats?.uplink.toInt() ?? 0)}',
    '↓ ${_formatSpeed(stats?.downlink.toInt() ?? 0)}',
  );
});

String? _lastPushed;

void _push(String top, String bottom) {
  final key = '$top\n$bottom';
  if (key == _lastPushed) return;
  _lastPushed = key;
  unawaited(trayManager.setTitleLines(top, bottom));
}

String _formatSpeed(int bytesPerSecond) {
  final kb = bytesPerSecond / 1024;
  if (kb < 1) return '0 KB/s';
  if (kb < 100) return '${kb.toStringAsFixed(1)} KB/s';
  if (kb < 1024) return '${kb.round()} KB/s';
  final mb = kb / 1024;
  if (mb < 100) return '${mb.toStringAsFixed(1)} MB/s';
  if (mb < 1024) return '${mb.round()} MB/s';
  return '${(mb / 1024).toStringAsFixed(2)} GB/s';
}
