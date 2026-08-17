/// Decimal megabits (10^6), matching professional speed-test reporting.
double bytesToMbps(int bytes, Duration elapsed) {
  final us = elapsed.inMicroseconds;
  if (bytes <= 0 || us <= 0) return 0;
  return (bytes * 8) / us;
}

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

int medianInt(List<int> values) {
  if (values.isEmpty) return 0;
  return median([for (final v in values) v.toDouble()]).round();
}

/// Linear interpolation percentile, [p] in 0..1.
double percentile(List<double> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  if (sorted.length == 1) return sorted.first;
  final clamped = p.clamp(0, 1);
  final rank = clamped * (sorted.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  if (lo == hi) return sorted[lo];
  final t = rank - lo;
  return sorted[lo] * (1 - t) + sorted[hi] * t;
}

/// Mean successive difference, the jitter number shown next to ping.
double meanSuccessiveDiff(List<int> samples) {
  if (samples.length < 2) return 0;
  var sum = 0.0;
  for (var i = 1; i < samples.length; i++) {
    sum += (samples[i] - samples[i - 1]).abs();
  }
  return sum / (samples.length - 1);
}

/// Drop samples more than 3× the median so one hung ping cannot explode jitter.
List<int> withoutPingOutliers(List<int> samples) {
  if (samples.length < 4) return List<int>.from(samples);
  final m = medianInt(samples);
  if (m <= 0) return List<int>.from(samples);
  final kept = samples.where((x) => x <= m * 3).toList();
  return kept.length >= 2 ? kept : List<int>.from(samples);
}

/// Drop the TLS/connect warmup ping so idle latency is not inflated.
List<int> dropWarmupSample(List<int> samples) {
  if (samples.length <= 1) return List<int>.from(samples);
  return samples.sublist(1);
}

String formatMbps(double? mbps) {
  if (mbps == null || !mbps.isFinite || mbps < 0) return '—';
  return mbps.toStringAsFixed(2);
}

String formatMs(num? ms) {
  if (ms == null || !ms.isFinite || ms < 0) return '—';
  if (ms is int || ms == ms.roundToDouble()) return '${ms.round()}';
  return ms < 10 ? ms.toStringAsFixed(1) : '${ms.round()}';
}

class CloudflareTrace {
  const CloudflareTrace({this.ip, this.loc, this.colo, this.http, this.tls});

  final String? ip;
  final String? loc;
  final String? colo;
  final String? http;
  final String? tls;

  String? city({required bool chinese}) {
    final code = colo;
    if (code == null || code.isEmpty) return null;
    final row = kCloudflareColoCities[code];
    if (row == null) return null;
    return chinese ? row.$2 : row.$1;
  }
}

CloudflareTrace parseCloudflareTrace(String body) {
  final map = <String, String>{};
  for (final line in body.split(RegExp(r'\r?\n'))) {
    final i = line.indexOf('=');
    if (i <= 0) continue;
    map[line.substring(0, i).trim()] = line.substring(i + 1).trim();
  }
  return CloudflareTrace(
    ip: _nonEmpty(map['ip']),
    loc: _nonEmpty(map['loc']),
    colo: _nonEmpty(map['colo']),
    http: _nonEmpty(map['http']),
    tls: _nonEmpty(map['tls']),
  );
}

String cloudflareServerLabel(CloudflareTrace? trace, {required bool chinese}) {
  if (trace == null) return 'Cloudflare';
  final colo = trace.colo;
  final city = trace.city(chinese: chinese);
  if (city != null && colo != null) return 'Cloudflare · $city ($colo)';
  if (colo != null) return 'Cloudflare · $colo';
  return 'Cloudflare';
}

String? _nonEmpty(String? value) {
  final v = value?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
}

/// Common Cloudflare PoP codes → (English, 中文).
const kCloudflareColoCities = <String, (String, String)>{
  'LAX': ('Los Angeles', '洛杉矶'),
  'SJC': ('San Jose', '圣何塞'),
  'SFO': ('San Francisco', '旧金山'),
  'SEA': ('Seattle', '西雅图'),
  'PDX': ('Portland', '波特兰'),
  'LAS': ('Las Vegas', '拉斯维加斯'),
  'PHX': ('Phoenix', '凤凰城'),
  'DEN': ('Denver', '丹佛'),
  'DFW': ('Dallas', '达拉斯'),
  'IAH': ('Houston', '休斯顿'),
  'ORD': ('Chicago', '芝加哥'),
  'MCI': ('Kansas City', '堪萨斯城'),
  'ATL': ('Atlanta', '亚特兰大'),
  'MIA': ('Miami', '迈阿密'),
  'IAD': ('Ashburn', '阿什本'),
  'EWR': ('Newark', '纽瓦克'),
  'BOS': ('Boston', '波士顿'),
  'YYZ': ('Toronto', '多伦多'),
  'YVR': ('Vancouver', '温哥华'),
  'LHR': ('London', '伦敦'),
  'MAN': ('Manchester', '曼彻斯特'),
  'CDG': ('Paris', '巴黎'),
  'AMS': ('Amsterdam', '阿姆斯特丹'),
  'FRA': ('Frankfurt', '法兰克福'),
  'MUC': ('Munich', '慕尼黑'),
  'MAD': ('Madrid', '马德里'),
  'MXP': ('Milan', '米兰'),
  'ARN': ('Stockholm', '斯德哥尔摩'),
  'WAW': ('Warsaw', '华沙'),
  'NRT': ('Tokyo', '东京'),
  'KIX': ('Osaka', '大阪'),
  'ICN': ('Seoul', '首尔'),
  'HKG': ('Hong Kong', '香港'),
  'TPE': ('Taipei', '台北'),
  'SIN': ('Singapore', '新加坡'),
  'BKK': ('Bangkok', '曼谷'),
  'MNL': ('Manila', '马尼拉'),
  'CGK': ('Jakarta', '雅加达'),
  'KUL': ('Kuala Lumpur', '吉隆坡'),
  'SYD': ('Sydney', '悉尼'),
  'MEL': ('Melbourne', '墨尔本'),
  'AKL': ('Auckland', '奥克兰'),
  'BOM': ('Mumbai', '孟买'),
  'DEL': ('Delhi', '德里'),
  'MAA': ('Chennai', '金奈'),
  'DXB': ('Dubai', '迪拜'),
  'BAH': ('Bahrain', '巴林'),
  'GRU': ('São Paulo', '圣保罗'),
  'SCL': ('Santiago', '圣地亚哥'),
  'JNB': ('Johannesburg', '约翰内斯堡'),
};
