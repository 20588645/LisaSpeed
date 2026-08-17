import 'package:hiddify/features/speed_test/model/speed_test_math.dart';

class SpeedTestTarget {
  const SpeedTestTarget({
    required this.id,
    required this.labelZh,
    required this.labelEn,
    required this.pingUri,
    required this.downloadUris,
    this.uploadUri,
    this.cloudflare = false,
    this.rangePing = false,
  });

  final String id;
  final String labelZh;
  final String labelEn;
  final Uri pingUri;
  final List<Uri> downloadUris;
  final Uri? uploadUri;
  final bool cloudflare;

  /// HEAD/GET of a tiny Range on the real download object — used when a
  /// README probe is blocked (403) but the ISO still serves.
  final bool rangePing;

  String label({required bool chinese}) => chinese ? labelZh : labelEn;
}

final kCloudflareSpeedTarget = SpeedTestTarget(
  id: 'cloudflare',
  labelZh: 'Cloudflare',
  labelEn: 'Cloudflare',
  pingUri: Uri.parse('https://speed.cloudflare.com/__down?bytes=1000'),
  downloadUris: [Uri.parse('https://speed.cloudflare.com/__down?bytes=80000000')],
  uploadUri: Uri.parse('https://speed.cloudflare.com/__up'),
  cloudflare: true,
);

final kHuaweiSpeedTarget = SpeedTestTarget(
  id: 'huawei',
  labelZh: '华为云镜像',
  labelEn: 'Huawei Cloud',
  pingUri: Uri.parse(
    'https://mirrors.huaweicloud.com/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso',
  ),
  downloadUris: [
    Uri.parse('https://mirrors.huaweicloud.com/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso'),
  ],
  rangePing: true,
);

final kNeteaseSpeedTarget = SpeedTestTarget(
  id: 'netease',
  labelZh: '网易镜像',
  labelEn: 'NetEase',
  pingUri: Uri.parse('https://mirrors.163.com/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso'),
  downloadUris: [
    Uri.parse('https://mirrors.163.com/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso'),
  ],
  rangePing: true,
);

final kTunaSpeedTarget = SpeedTestTarget(
  id: 'tuna',
  labelZh: '清华 TUNA 镜像',
  labelEn: 'Tsinghua TUNA',
  pingUri: Uri.parse('https://mirrors.tuna.tsinghua.edu.cn/debian/README'),
  downloadUris: [
    Uri.parse('https://mirrors.tuna.tsinghua.edu.cn/debian-cd/current/amd64/iso-dvd/debian-13.6.0-amd64-DVD-1.iso'),
    Uri.parse('https://mirrors.tuna.tsinghua.edu.cn/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso'),
  ],
  rangePing: true,
);

final kAliyunSpeedTarget = SpeedTestTarget(
  id: 'aliyun',
  labelZh: '阿里云镜像',
  labelEn: 'Aliyun',
  pingUri: Uri.parse('https://mirrors.aliyun.com/debian/README'),
  downloadUris: [Uri.parse('https://mirrors.aliyun.com/debian/ls-lR.gz')],
);

/// Direct (China ISP) last-mile probes. Cloudflare is only a fallback.
final kDirectSpeedTargets = [kHuaweiSpeedTarget, kNeteaseSpeedTarget, kTunaSpeedTarget, kAliyunSpeedTarget];

final kAllSpeedTargets = [...kDirectSpeedTargets, kCloudflareSpeedTarget];

/// [preferDomestic] keeps a nearby China mirror even when Cloudflare pings faster.
SpeedTestTarget pickFastestTarget(
  List<(SpeedTestTarget target, int rttMs)> samples, {
  bool preferDomestic = false,
}) {
  final ok = samples.where((s) => s.$2 < 60000).toList()..sort((a, b) => a.$2.compareTo(b.$2));
  if (ok.isEmpty) return kCloudflareSpeedTarget;
  if (preferDomestic) {
    final domestic = ok.where((s) => !s.$1.cloudflare).toList();
    if (domestic.isNotEmpty) return domestic.first.$1;
  }
  return ok.first.$1;
}

String speedTestServerLabel({
  required String? serverId,
  CloudflareTrace? trace,
  required bool chinese,
}) {
  for (final target in kAllSpeedTargets) {
    if (target.id != serverId) continue;
    if (target.cloudflare) return cloudflareServerLabel(trace, chinese: chinese);
    return target.label(chinese: chinese);
  }
  return cloudflareServerLabel(trace, chinese: chinese);
}
