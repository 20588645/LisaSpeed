/// Clash API on the privileged TUN helper. Must match
/// `tunnelClashAPIAddr` in hiddify-core tunnelservice.
const kTunnelClashApiAddr = '127.0.0.1:16757';
const kTunnelClashConnectionsUrl = 'http://$kTunnelClashApiAddr/connections';

enum OfficeMediaExit { idle, node, direct, mixed }

class OfficeMediaAppTraffic {
  const OfficeMediaAppTraffic({
    required this.exit,
    required this.upSpeed,
    required this.downSpeed,
    required this.upTotal,
    required this.downTotal,
    required this.connections,
  });

  static const empty = OfficeMediaAppTraffic(
    exit: OfficeMediaExit.idle,
    upSpeed: 0,
    downSpeed: 0,
    upTotal: 0,
    downTotal: 0,
    connections: 0,
  );

  final OfficeMediaExit exit;
  final int upSpeed;
  final int downSpeed;
  final int upTotal;
  final int downTotal;
  final int connections;

  int get total => upTotal + downTotal;

  OfficeMediaAppTraffic copyWith({
    OfficeMediaExit? exit,
    int? upSpeed,
    int? downSpeed,
    int? upTotal,
    int? downTotal,
    int? connections,
  }) {
    return OfficeMediaAppTraffic(
      exit: exit ?? this.exit,
      upSpeed: upSpeed ?? this.upSpeed,
      downSpeed: downSpeed ?? this.downSpeed,
      upTotal: upTotal ?? this.upTotal,
      downTotal: downTotal ?? this.downTotal,
      connections: connections ?? this.connections,
    );
  }
}

class ClashTrackedConn {
  const ClashTrackedConn({
    required this.id,
    required this.processPath,
    required this.chains,
    required this.upload,
    required this.download,
  });

  final String id;
  final String processPath;
  final List<String> chains;
  final int upload;
  final int download;

  bool get viaNode => chains.contains('socks-out');
  bool get viaDirect => chains.contains('direct-out');
}

String? matchOfficeMediaApp(String processPath, List<String> apps) {
  if (processPath.isEmpty || apps.isEmpty) return null;
  final base = processPath.split('/').last;
  for (final app in apps) {
    if (app.isEmpty) continue;
    if (processPath.contains('$app.app')) return app;
    if (base == app || base.startsWith('$app Helper') || base.startsWith('$app Login')) {
      return app;
    }
  }
  return null;
}

List<ClashTrackedConn> parseClashConnections(Object? json) {
  if (json is! Map) return const [];
  final raw = json['connections'];
  if (raw is! List) return const [];
  final out = <ClashTrackedConn>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final metadata = item['metadata'];
    final processPath = metadata is Map ? '${metadata['processPath'] ?? ''}' : '';
    final chains = <String>[
      if (item['chains'] is List)
        for (final chain in item['chains'] as List) '$chain',
    ];
    out.add(
      ClashTrackedConn(
        id: '${item['id'] ?? ''}',
        processPath: processPath,
        chains: chains,
        upload: _asInt(item['upload']),
        download: _asInt(item['download']),
      ),
    );
  }
  return out;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
