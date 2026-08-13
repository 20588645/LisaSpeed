import 'dart:async';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime traffic counters persisted across disconnects and app restarts.
///
/// The core reports per-session totals that restart from zero on every
/// reconnect, so this notifier accumulates the deltas between consecutive
/// stats frames instead (a counter going backwards marks a new session).
/// Totals are flushed to preferences at most every [_flushInterval] and
/// immediately on session boundaries.
final totalTrafficProvider = NotifierProvider<TotalTrafficNotifier, ({int uplink, int downlink})>(TotalTrafficNotifier.new);

class TotalTrafficNotifier extends Notifier<({int uplink, int downlink})> {
  static const _upKey = 'total_traffic_uplink';
  static const _downKey = 'total_traffic_downlink';
  static const _flushInterval = Duration(seconds: 5);

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider).requireValue;

  int _sessionUp = 0;
  int _sessionDown = 0;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _dirty = false;

  @override
  ({int uplink, int downlink}) build() {
    ref.listen(statsNotifierProvider, (previous, next) {
      final stats = next.asData?.value;
      if (stats == null) return;
      _onFrame(stats.uplinkTotal.toInt(), stats.downlinkTotal.toInt());
    });
    return (uplink: _prefs.getInt(_upKey) ?? 0, downlink: _prefs.getInt(_downKey) ?? 0);
  }

  void _onFrame(int up, int down) {
    final sessionRestarted = up < _sessionUp || down < _sessionDown;
    final deltaUp = sessionRestarted ? up : up - _sessionUp;
    final deltaDown = sessionRestarted ? down : down - _sessionDown;
    _sessionUp = up;
    _sessionDown = down;
    if (deltaUp > 0 || deltaDown > 0) {
      state = (uplink: state.uplink + deltaUp, downlink: state.downlink + deltaDown);
      _dirty = true;
    }
    _flush(force: sessionRestarted);
  }

  void _flush({bool force = false}) {
    if (!_dirty) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastFlush) < _flushInterval) return;
    _lastFlush = now;
    _dirty = false;
    unawaited(_prefs.setInt(_upKey, state.uplink));
    unawaited(_prefs.setInt(_downKey, state.downlink));
  }
}
