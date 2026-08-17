import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/ip_purity/model/ip_purity_report.dart';
import 'package:hiddify/features/ip_purity/notifier/ip_purity_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class IpPurityPage extends HookConsumerWidget {
  const IpPurityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final state = ref.watch(ipPurityProvider);
    final connected = ref.watch(serviceRunningProvider);
    final busy = state.testing;
    final visible = TickerMode.of(context);

    useEffect(() {
      if (!visible) return null;
      Future.microtask(() => ref.read(ipPurityProvider.notifier).inspectIfIdle());
      return null;
    }, [visible]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.pageIntro(
              context,
              title: t.pages.ipPurity.title,
              subtitle: t.pages.ipPurity.subtitle,
              action: TechUi.primaryButton(
                context,
                label: busy ? t.pages.ipPurity.inspecting : t.pages.ipPurity.inspect,
                onPressed: busy ? null : () => ref.read(ipPurityProvider.notifier).inspect(),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 920;
                final twoCol = constraints.maxWidth >= 720;
                return ListView(
                  padding: TechUi.pageBodyPadding,
                  children: [
                    Text(
                      connected ? t.pages.ipPurity.hintConnected : t.pages.ipPurity.hintDisconnected,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (state.report != null && state.report!.viaProxy != connected) ...[
                      const Gap(8),
                      Text(
                        t.pages.ipPurity.hintStale,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TechUi.warnOf(context)),
                      ),
                    ],
                    const Gap(14),
                    if (busy && state.report == null)
                      const _LoadingPanel()
                    else if (state.report == null && state.failed)
                      _EmptyPanel(text: t.pages.ipPurity.fail)
                    else if (state.report == null)
                      _EmptyPanel(text: t.pages.ipPurity.idle)
                    else ...[
                      if (state.failed) ...[
                        Text(
                          t.pages.ipPurity.fail,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TechUi.dangerOf(context)),
                        ),
                        const Gap(12),
                      ],
                      _ReportBody(report: state.report!, wide: wide, twoCol: twoCol),
                    ],
                    const Gap(20),
                    Text(
                      t.pages.ipPurity.footer,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: TechUi.panelDecoration(context),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: ConnectionButtonTheme.accentOf(context)),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({
    required this.report,
    required this.wide,
    required this.twoCol,
  });

  final IpPurityReport report;
  final bool wide;
  final bool twoCol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final scoreCard = _ScoreCard(report: report);
    final geoCard = _GeoCard(report: report);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: scoreCard),
                const SizedBox(width: 12),
                Expanded(flex: 6, child: geoCard),
              ],
            ),
          )
        else ...[
          scoreCard,
          const Gap(12),
          geoCard,
        ],
        const Gap(16),
        _SectionHead(title: t.pages.ipPurity.signals),
        const Gap(8),
        _SignalsRow(report: report, twoCol: twoCol),
        const Gap(16),
        _SectionHead(
          title: t.pages.ipPurity.scenes,
          trailing: TechUi.tag(context, t.pages.ipPurity.sceneCount(count: 4)),
        ),
        const Gap(8),
        _ScenesRow(report: report, twoCol: twoCol),
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _ScoreCard extends ConsumerWidget {
  const _ScoreCard({required this.report});

  final IpPurityReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final color = _gradeColor(context, report.grade);
    final location = [
      if (report.flagEmoji.isNotEmpty) report.flagEmoji,
      if (report.locationLabel.isNotEmpty) report.locationLabel,
    ].join(' ');
    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScoreRing(score: report.score, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_gradeLabel(t, report.grade)} · ${_lineLabel(t, report.lineType)}',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Gap(8),
                    Text(
                      report.ip,
                      style: TechUi.mono(context, size: 18),
                    ),
                    if (location.isNotEmpty) ...[
                      const Gap(4),
                      Text(
                        location,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Gap(14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                label: report.nativeKnown
                    ? (report.nativeIp ? t.pages.ipPurity.native : t.pages.ipPurity.notNative)
                    : t.pages.ipPurity.nativeUnknown,
                color: report.nativeIp
                    ? ConnectionButtonTheme.accentOf(context)
                    : theme.colorScheme.onSurfaceVariant,
              ),
              _Pill(
                label: report.proxyLike ? t.pages.ipPurity.hasProxy : t.pages.ipPurity.noProxy,
                color: report.proxyLike ? TechUi.warnOf(context) : ConnectionButtonTheme.accentOf(context),
              ),
              _Pill(
                label: report.viaProxy ? t.pages.ipPurity.viaProxy : t.pages.ipPurity.viaDirect,
                color: report.viaProxy ? ConnectionButtonTheme.accentOf(context) : theme.colorScheme.onSurfaceVariant,
              ),
              _Pill(
                label: t.pages.ipPurity.updatedAt(time: DateFormat.Hms().format(report.testedAt)),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GeoCard extends ConsumerWidget {
  const _GeoCard({required this.report});

  final IpPurityReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final dash = t.pages.ipPurity.none;
    final coords = report.lat != null && report.lon != null
        ? '${report.lat!.toStringAsFixed(4)}, ${report.lon!.toStringAsFixed(3)}'
        : dash;
    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.pages.ipPurity.geoTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TechUi.ghostButton(
                context,
                label: t.pages.ipPurity.copy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _copyText(t, report)));
                  ref.read(inAppNotificationControllerProvider).showSuccessToast(t.pages.ipPurity.copied);
                },
              ),
            ],
          ),
          const Gap(8),
          _Kv(label: t.pages.ipPurity.asn, value: report.asn ?? dash),
          _Kv(label: t.pages.ipPurity.asnOwner, value: report.asnName ?? dash),
          _Kv(label: t.pages.ipPurity.isp, value: report.isp ?? dash),
          _Kv(label: t.pages.ipPurity.lineType, value: _lineLabel(t, report.lineType)),
          _Kv(label: t.pages.ipPurity.registry, value: report.registryCountry ?? dash),
          _Kv(label: t.pages.ipPurity.coords, value: coords),
          _Kv(label: t.pages.ipPurity.city, value: report.city ?? dash),
          _Kv(label: t.pages.ipPurity.sources, value: report.sources.isEmpty ? dash : report.sources.join(' · ')),
        ],
      ),
    );
  }
}

class _SignalsRow extends ConsumerWidget {
  const _SignalsRow({required this.report, required this.twoCol});

  final IpPurityReport report;
  final bool twoCol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final hosting = report.hosting;
    final devices = report.deviceCount;
    final sharingHigh = devices != null ? devices >= 11 : hosting;
    final sharingMid = devices != null && devices >= 5 && devices <= 10;
    final sharingValue = sharingHigh
        ? t.pages.ipPurity.sharingHigh
        : sharingMid
        ? t.pages.ipPurity.sharingMid
        : t.pages.ipPurity.sharingLow;
    final sharingProgress = devices == null
        ? (hosting ? 0.72 : 0.22)
        : devices <= 1
        ? 0.18
        : devices <= 10
        ? 0.40
        : (0.55 + devices / 80).clamp(0.55, 0.95);
    final items = [
      _SignalData(
        title: t.pages.ipPurity.sharing,
        value: sharingValue,
        hint: devices == null
            ? (sharingHigh ? t.pages.ipPurity.riskHigh : t.pages.ipPurity.riskLow)
            : t.pages.ipPurity.sharingDevices(count: devices),
        progress: sharingProgress,
        ok: !sharingHigh,
      ),
      _SignalData(
        title: t.pages.ipPurity.proxyDetect,
        value: report.proxyLike ? t.pages.ipPurity.found : t.pages.ipPurity.notFound,
        hint: report.vpn
            ? t.pages.ipPurity.vpn
            : report.tor
            ? t.pages.ipPurity.tor
            : report.externalRisk == null
            ? null
            : t.pages.ipPurity.externalRisk(value: report.externalRisk!),
        ok: !report.proxyLike,
      ),
      _SignalData(
        title: t.pages.ipPurity.ipAttr,
        value: report.nativeKnown
            ? (report.nativeIp ? t.pages.ipPurity.native : t.pages.ipPurity.notNative)
            : t.pages.ipPurity.nativeUnknown,
        hint: report.mobile ? t.pages.ipPurity.lineMobile : null,
        ok: report.nativeIp,
      ),
      _SignalData(
        title: t.pages.ipPurity.streaming,
        value: hosting || report.proxyLike ? t.pages.ipPurity.streamingWarn : t.pages.ipPurity.streamingOk,
        ok: !hosting && !report.proxyLike,
      ),
    ];
    return _Grid(twoCol: twoCol, children: [for (final item in items) _SignalCard(data: item)]);
  }
}

class _ScenesRow extends ConsumerWidget {
  const _ScenesRow({required this.report, required this.twoCol});

  final IpPurityReport report;
  final bool twoCol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final items = [
      (IpSceneKind.tiktok, t.pages.ipPurity.sceneTiktok, t.pages.ipPurity.sceneTiktokHint),
      (IpSceneKind.commerce, t.pages.ipPurity.sceneCommerce, t.pages.ipPurity.sceneCommerceHint),
      (IpSceneKind.social, t.pages.ipPurity.sceneSocial, t.pages.ipPurity.sceneSocialHint),
      (IpSceneKind.ai, t.pages.ipPurity.sceneAi, t.pages.ipPurity.sceneAiHint),
    ];
    return _Grid(
      twoCol: twoCol,
      children: [
        for (final item in items)
          _SceneCard(title: item.$2, hint: item.$3, verdict: report.verdictFor(item.$1)),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.twoCol, required this.children});

  final bool twoCol;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 920
            ? 4
            : twoCol
            ? 2
            : 1;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.sublist(i, math.min(i + cols, children.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, child) in slice.indexed) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(child: child),
                  ],
                  for (var j = slice.length; j < cols; j++) ...[const SizedBox(width: 10), const Expanded(child: SizedBox())],
                ],
              ),
            ),
          );
          if (i + cols < children.length) rows.add(const SizedBox(height: 10));
        }
        return Column(children: rows);
      },
    );
  }
}

class _SignalData {
  const _SignalData({
    required this.title,
    required this.value,
    required this.ok,
    this.hint,
    this.progress,
  });

  final String title;
  final String value;
  final String? hint;
  final bool ok;
  final double? progress;
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.data});

  final _SignalData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = data.ok ? ConnectionButtonTheme.accentOf(context) : TechUi.warnOf(context);
    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(data.value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          if (data.progress != null) ...[
            const Gap(8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: data.progress,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.16),
              ),
            ),
          ],
          if (data.hint != null) ...[
            const Gap(6),
            Text(data.hint!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _SceneCard extends ConsumerWidget {
  const _SceneCard({required this.title, required this.hint, required this.verdict});

  final String title;
  final String hint;
  final IpSceneVerdict verdict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final color = switch (verdict) {
      IpSceneVerdict.perfect => ConnectionButtonTheme.accentOf(context),
      IpSceneVerdict.tryable => theme.colorScheme.onSurfaceVariant,
      IpSceneVerdict.avoid => TechUi.warnOf(context),
    };
    final label = switch (verdict) {
      IpSceneVerdict.perfect => t.pages.ipPurity.verdictPerfect,
      IpSceneVerdict.tryable => t.pages.ipPurity.verdictTry,
      IpSceneVerdict.avoid => t.pages.ipPurity.verdictAvoid,
    };
    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              _Pill(label: label, color: color),
            ],
          ),
          const Gap(6),
          Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: score.clamp(0, 100) / 100,
          color: color,
          track: color.withValues(alpha: 0.16),
        ),
        child: Center(
          child: Text(
            '$score',
            style: TechUi.mono(context, size: 28, color: color),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 7;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.track != track;
}

Color _gradeColor(BuildContext context, IpPurityGrade grade) {
  return switch (grade) {
    IpPurityGrade.excellent || IpPurityGrade.good => ConnectionButtonTheme.accentOf(context),
    IpPurityGrade.fair => TechUi.warnOf(context),
    IpPurityGrade.poor || IpPurityGrade.bad => TechUi.dangerOf(context),
  };
}

String _gradeLabel(Translations t, IpPurityGrade grade) {
  return switch (grade) {
    IpPurityGrade.excellent => t.pages.ipPurity.gradeExcellent,
    IpPurityGrade.good => t.pages.ipPurity.gradeGood,
    IpPurityGrade.fair => t.pages.ipPurity.gradeFair,
    IpPurityGrade.poor => t.pages.ipPurity.gradePoor,
    IpPurityGrade.bad => t.pages.ipPurity.gradeBad,
  };
}

String _lineLabel(Translations t, IpLineType type) {
  return switch (type) {
    IpLineType.residential => t.pages.ipPurity.lineResidential,
    IpLineType.business => t.pages.ipPurity.lineBusiness,
    IpLineType.isp => t.pages.ipPurity.lineIsp,
    IpLineType.hosting => t.pages.ipPurity.lineHosting,
    IpLineType.mobile => t.pages.ipPurity.lineMobile,
    IpLineType.vpn => t.pages.ipPurity.vpn,
    IpLineType.unknown => t.pages.ipPurity.lineUnknown,
  };
}

String _copyText(Translations t, IpPurityReport report) {
  final dash = t.pages.ipPurity.none;
  return [
    '${t.pages.ipPurity.inspect}: ${report.ip}',
    '${t.pages.ipPurity.score}: ${report.score} ${_gradeLabel(t, report.grade)}',
    '${t.pages.ipPurity.country}: ${report.country ?? dash}',
    '${t.pages.ipPurity.region}: ${report.region ?? dash}',
    '${t.pages.ipPurity.city}: ${report.city ?? dash}',
    '${t.pages.ipPurity.asn}: ${report.asn ?? dash}',
    '${t.pages.ipPurity.asnOwner}: ${report.asnName ?? dash}',
    '${t.pages.ipPurity.isp}: ${report.isp ?? dash}',
    '${t.pages.ipPurity.lineType}: ${_lineLabel(t, report.lineType)}',
    '${t.pages.ipPurity.registry}: ${report.registryCountry ?? dash}',
    '${t.pages.ipPurity.native}: ${report.nativeKnown ? (report.nativeIp ? t.pages.ipPurity.native : t.pages.ipPurity.notNative) : t.pages.ipPurity.nativeUnknown}',
    '${t.pages.ipPurity.proxyDetect}: ${report.proxyLike ? t.pages.ipPurity.found : t.pages.ipPurity.notFound}',
    '${t.pages.ipPurity.datacenter}: ${report.hosting}',
    '${t.pages.ipPurity.sources}: ${report.sources.join(', ')}',
    '${t.pages.ipPurity.vpn}: ${report.vpn}',
    '${t.pages.ipPurity.tor}: ${report.tor}',
    '${t.pages.ipPurity.abuser}: ${report.abuser}',
  ].join('\n');
}
