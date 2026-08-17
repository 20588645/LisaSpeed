import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/model/office_media_traffic.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final officeMediaTrafficProvider =
    NotifierProvider<OfficeMediaTrafficNotifier, Map<String, OfficeMediaAppTraffic>>(OfficeMediaTrafficNotifier.new);

class _OpenConn {
  const _OpenConn({required this.app, required this.up, required this.down, required this.viaNode, required this.viaDirect});

  final String app;
  final int up;
  final int down;
  final bool viaNode;
  final bool viaDirect;
}

class OfficeMediaTrafficNotifier extends Notifier<Map<String, OfficeMediaAppTraffic>> {
  static const _prefsKey = 'office-media-app-traffic';
  static const _flushInterval = Duration(seconds: 5);
  static const _pollInterval = Duration(seconds: 1);

  final HttpClient _client = HttpClient()..findProxy = (_) => 'DIRECT';
  final Map<String, _OpenConn> _open = {};
  final Map<String, ({int up, int down})> _lifetime = {};
  final Map<String, ({int up, int down})> _lastTick = {};
  Timer? _timer;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastTickAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _dirty = false;
  bool _inflight = false;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider).requireValue;

  @override
  Map<String, OfficeMediaAppTraffic> build() {
    if (!PlatformUtils.isMacOS) return const {};
    _loadPrefs();
    ref.onDispose(() {
      _timer?.cancel();
      _client.close(force: true);
      _flush(force: true);
    });
    ref.listen(serviceRunningProvider, (_, _) => _syncTimer());
    ref.listen(ConfigOptions.officeMediaProxy, (_, _) => _syncTimer());
    ref.listen(ConfigOptions.officeMediaApps, (_, next) {
      _syncTimer();
      state = _rowsFor(next);
    });
    _syncTimer();
    return _rowsFor(ref.read(ConfigOptions.officeMediaApps));
  }

  Future<void> refreshNow() async {
    await _poll();
  }

  void _syncTimer() {
    final enabled =
        PlatformUtils.isMacOS && ref.read(ConfigOptions.officeMediaProxy) && ref.read(ConfigOptions.officeMediaApps).isNotEmpty;
    final running = ref.read(serviceRunningProvider);
    if (!enabled || !running) {
      _timer?.cancel();
      _timer = null;
      _open.clear();
      _lastTick.clear();
      state = _rowsFor(ref.read(ConfigOptions.officeMediaApps));
      return;
    }
    _timer ??= Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  Future<void> _poll() async {
    if (_inflight) return;
    _inflight = true;
    try {
      final apps = ref.read(ConfigOptions.officeMediaApps);
      final conns = await _fetchConnections();
      if (conns != null) {
        _ingest(conns, apps);
        _flush();
      }
      state = _rowsFor(apps);
    } finally {
      _inflight = false;
    }
  }

  Future<List<ClashTrackedConn>?> _fetchConnections() async {
    try {
      final req = await _client.getUrl(Uri.parse(kTunnelClashConnectionsUrl));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(milliseconds: 800));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      return parseClashConnections(jsonDecode(body));
    } catch (_) {
      return null;
    }
  }

  void _ingest(List<ClashTrackedConn> conns, List<String> apps) {
    final seen = <String>{};
    for (final conn in conns) {
      if (conn.id.isEmpty) continue;
      final app = matchOfficeMediaApp(conn.processPath, apps);
      if (app == null) continue;
      seen.add(conn.id);
      final prev = _open[conn.id];
      final deltaUp = prev == null ? conn.upload : (conn.upload - prev.up).clamp(0, conn.upload);
      final deltaDown = prev == null ? conn.download : (conn.download - prev.down).clamp(0, conn.download);
      _open[conn.id] = _OpenConn(
        app: app,
        up: conn.upload,
        down: conn.download,
        viaNode: conn.viaNode,
        viaDirect: conn.viaDirect,
      );
      if (deltaUp == 0 && deltaDown == 0) continue;
      final life = _lifetime[app] ?? (up: 0, down: 0);
      _lifetime[app] = (up: life.up + deltaUp, down: life.down + deltaDown);
      _dirty = true;
    }
    _open.removeWhere((id, _) => !seen.contains(id));
  }

  Map<String, OfficeMediaAppTraffic> _rowsFor(List<String> apps) {
    final now = DateTime.now();
    final dtMs = _lastTickAt.millisecondsSinceEpoch == 0 ? 1000 : now.difference(_lastTickAt).inMilliseconds.clamp(400, 4000);
    final dt = dtMs / 1000.0;
    _lastTickAt = now;

    final node = <String, int>{};
    final direct = <String, int>{};
    final conns = <String, int>{};
    for (final open in _open.values) {
      conns[open.app] = (conns[open.app] ?? 0) + 1;
      if (open.viaNode) node[open.app] = (node[open.app] ?? 0) + 1;
      if (open.viaDirect) direct[open.app] = (direct[open.app] ?? 0) + 1;
    }

    final byApp = <String, OfficeMediaAppTraffic>{};
    for (final app in apps) {
      if (app.isEmpty) continue;
      final life = _lifetime[app] ?? (up: 0, down: 0);
      final prev = _lastTick[app] ?? life;
      final upSpeed = ((life.up - prev.up) / dt).round().clamp(0, 1 << 30);
      final downSpeed = ((life.down - prev.down) / dt).round().clamp(0, 1 << 30);
      _lastTick[app] = life;
      byApp[app] = OfficeMediaAppTraffic(
        exit: _exitFor(node[app] ?? 0, direct[app] ?? 0),
        upSpeed: upSpeed,
        downSpeed: downSpeed,
        upTotal: life.up,
        downTotal: life.down,
        connections: conns[app] ?? 0,
      );
    }
    return byApp;
  }

  static OfficeMediaExit _exitFor(int node, int direct) {
    if (node > 0 && direct > 0) return OfficeMediaExit.mixed;
    if (node > 0) return OfficeMediaExit.node;
    if (direct > 0) return OfficeMediaExit.direct;
    return OfficeMediaExit.idle;
  }

  void _loadPrefs() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return;
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        _lifetime['${entry.key}'] = (up: _asInt(value['up']), down: _asInt(value['down']));
      }
    } catch (_) {}
  }

  void _flush({bool force = false}) {
    if (!_dirty) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastFlush) < _flushInterval) return;
    _lastFlush = now;
    _dirty = false;
    unawaited(
      _prefs.setString(
        _prefsKey,
        jsonEncode({
          for (final e in _lifetime.entries) e.key: {'up': e.value.up, 'down': e.value.down},
        }),
      ),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
