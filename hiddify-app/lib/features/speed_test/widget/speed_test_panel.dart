import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/line_health/notifier/line_health_notifier.dart';
import 'package:hiddify/features/link_test/notifier/link_test_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/features/speed_test/data/speed_test_targets.dart';
import 'package:hiddify/features/speed_test/model/speed_test_math.dart';
import 'package:hiddify/features/speed_test/model/speed_test_report.dart';
import 'package:hiddify/features/speed_test/notifier/speed_test_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class SpeedTestPanel extends ConsumerWidget {
  const SpeedTestPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final state = ref.watch(speedTestProvider);
    final connected = ref.watch(serviceRunningProvider);
    final siteBusy = ref.watch(linkTestProvider).testingIds.isNotEmpty;
    final healthBusy = ref.watch(lineHealthProvider).running;
    final locale = ref.watch(localePreferencesProvider);
    final chinese = locale == AppLocale.zhCn || locale == AppLocale.zhTw;
    final proxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final nodeName = proxy == null
        ? null
        : proxyDisplayTitle(proxy, chinese: chinese, autoLabel: t.pages.proxies.autoSelect);
    final viaProxy = state.viaProxy ?? connected;
    final errorText = _errorText(t, state);

    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.pages.speedTest.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: TechUi.statusChip(
                  context,
                  viaProxy
                      ? (nodeName == null ? t.pages.speedTest.viaProxy : t.pages.speedTest.viaNode(name: nodeName))
                      : t.pages.speedTest.viaDirect,
                  active: viaProxy,
                ),
              ),
            ],
          ),
          const Gap(6),
          Text(
            connected ? t.pages.speedTest.hintConnected : t.pages.speedTest.hintDisconnected,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 640;
              final go = _GoButton(
                running: state.running,
                fraction: state.fraction,
                label: state.running ? t.pages.speedTest.stop : t.pages.speedTest.go,
                enabled: (!siteBusy && !healthBusy) || state.running,
                onPressed: () => ref.read(speedTestProvider.notifier).toggle(),
              );
              final down = _BigMetric(
                label: t.pages.speedTest.download,
                unit: t.pages.speedTest.unitMbps,
                value: formatMbps(state.downloadMbps),
                emphasize: state.phase == SpeedTestPhase.download,
              );
              final up = _BigMetric(
                label: t.pages.speedTest.upload,
                unit: t.pages.speedTest.unitMbps,
                value: state.uploadFailed ? '—' : formatMbps(state.uploadMbps),
                emphasize: state.phase == SpeedTestPhase.upload,
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: down),
                    go,
                    Expanded(child: up),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: down),
                      Expanded(child: up),
                    ],
                  ),
                  const Gap(16),
                  go,
                ],
              );
            },
          ),
          const Gap(18),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _PingMetric(
                icon: Icons.schedule_rounded,
                label: t.pages.speedTest.idlePing,
                value: formatMs(state.idlePingMs),
                delayMs: state.idlePingMs ?? 0,
              ),
              _PingMetric(
                icon: Icons.download_rounded,
                label: t.pages.speedTest.downPing,
                value: formatMs(state.downloadLoadedPingMs),
                delayMs: state.downloadLoadedPingMs ?? 0,
              ),
              _PingMetric(
                icon: Icons.upload_rounded,
                label: t.pages.speedTest.upPing,
                value: formatMs(state.uploadLoadedPingMs),
                delayMs: state.uploadLoadedPingMs ?? 0,
              ),
              _PingMetric(
                icon: Icons.graphic_eq_rounded,
                label: t.pages.speedTest.jitter,
                value: formatMs(state.jitterMs),
                delayMs: state.jitterMs?.round() ?? 0,
              ),
            ],
          ),
          const Gap(14),
          Row(
            children: [
              Icon(Icons.dns_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  speedTestServerLabel(
                    serverId: state.serverId,
                    trace: state.trace,
                    chinese: chinese,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TechUi.mono(
                    context,
                    size: 12,
                    weight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (state.testedAt != null)
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(state.testedAt!),
                  style: TechUi.mono(
                    context,
                    size: 10,
                    weight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (errorText != null) ...[
            const Gap(10),
            Text(
              errorText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TechUi.dangerOf(context)),
            ),
          ] else if (state.uploadFailed) ...[
            const Gap(10),
            Text(
              t.pages.speedTest.failUpload,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: TechUi.warnOf(context)),
            ),
          ],
          const Gap(10),
          Text(
            t.pages.speedTest.methodNote,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String? _errorText(Translations t, SpeedTestState state) {
    if (state.phase == SpeedTestPhase.cancelled && !state.running && !state.hasResult) {
      return t.pages.speedTest.failCancelled;
    }
    if ((state.downloadMbps ?? 0) > 0) return null;
    if (state.phase != SpeedTestPhase.failed || state.failure == null) return null;
    return switch (state.failure!) {
      SpeedTestFailureKind.timeout => t.pages.speedTest.failTimeout,
      SpeedTestFailureKind.network =>
        (state.viaProxy ?? false) ? t.pages.speedTest.failNetwork : t.pages.speedTest.failUnreachable,
      SpeedTestFailureKind.tls => t.pages.speedTest.failTls,
      SpeedTestFailureKind.cancelled => t.pages.speedTest.failCancelled,
      SpeedTestFailureKind.unknown => t.pages.speedTest.failUnknown,
    };
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({
    required this.label,
    required this.unit,
    required this.value,
    required this.emphasize,
  });

  final String label;
  final String unit;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Text(
          '$label $unit',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: emphasize ? accent : muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TechUi.mono(
              context,
              size: 42,
              letterSpacing: -1.2,
              color: emphasize ? accent : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _PingMetric extends StatelessWidget {
  const _PingMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.delayMs,
  });

  final IconData icon;
  final String label;
  final String value;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final color = value == '—'
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : TechUi.delayColor(context, delayMs);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$value ${value == '—' ? '' : 'ms'}'.trim(),
              style: TechUi.mono(context, size: 16, color: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoButton extends StatelessWidget {
  const _GoButton({
    required this.running,
    required this.fraction,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final bool running;
  final double fraction;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final track = ConnectionButtonTheme.lineOf(context);
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 112,
            height: 112,
            child: CustomPaint(
              painter: _GoRingPainter(
                progress: running ? fraction.clamp(0.04, 1) : 0,
                accent: accent,
                track: track,
              ),
              child: Center(
                child: Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: Text(
                    label,
                    style: TechUi.mono(
                      context,
                      size: running ? 16 : 22,
                      weight: FontWeight.w800,
                      letterSpacing: running ? 0.6 : 1.4,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoRingPainter extends CustomPainter {
  _GoRingPainter({required this.progress, required this.accent, required this.track});

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 5;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(c, radius, trackPaint);
    final fill = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(c, radius - 3, fill);
    if (progress > 0) {
      final arc = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent || oldDelegate.track != track;
}
