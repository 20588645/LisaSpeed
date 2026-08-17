import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/widget/mac_app_icon.dart';
import 'package:hiddify/features/stats/model/office_media_traffic.dart';
import 'package:hiddify/features/stats/notifier/office_media_traffic_notifier.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OfficeMediaTrafficRows extends ConsumerWidget {
  const OfficeMediaTrafficRows({super.key, required this.apps, this.onRemove, this.compact = false});

  final List<String> apps;
  final ValueChanged<String>? onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(officeMediaTrafficProvider);
    return Column(
      children: [
        for (final (i, name) in apps.indexed) ...[
          if (i > 0) SizedBox(height: compact ? 6 : 8),
          _AppTrafficRow(
            name: name,
            traffic: stats[name] ?? OfficeMediaAppTraffic.empty,
            compact: compact,
            onRemove: onRemove == null ? null : () => onRemove!(name),
            nodeLabel: t.pages.settings.general.officeMediaExitNode,
            directLabel: t.pages.settings.general.officeMediaExitDirect,
            mixedLabel: t.pages.settings.general.officeMediaExitMixed,
            idleLabel: t.pages.settings.general.officeMediaExitIdle,
            totalLabel: t.pages.settings.general.officeMediaStatsTotal,
          ),
        ],
      ],
    );
  }
}

class _AppTrafficRow extends StatelessWidget {
  const _AppTrafficRow({
    required this.name,
    required this.traffic,
    required this.nodeLabel,
    required this.directLabel,
    required this.mixedLabel,
    required this.idleLabel,
    required this.totalLabel,
    this.compact = false,
    this.onRemove,
  });

  final String name;
  final OfficeMediaAppTraffic traffic;
  final String nodeLabel;
  final String directLabel;
  final String mixedLabel;
  final String idleLabel;
  final String totalLabel;
  final bool compact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = ConnectionButtonTheme.accentOf(context);
    final color = switch (traffic.exit) {
      OfficeMediaExit.node => accent,
      OfficeMediaExit.direct || OfficeMediaExit.mixed => TechUi.warnOf(context),
      OfficeMediaExit.idle => muted,
    };
    final label = switch (traffic.exit) {
      OfficeMediaExit.node => nodeLabel,
      OfficeMediaExit.direct => directLabel,
      OfficeMediaExit.mixed => mixedLabel,
      OfficeMediaExit.idle => idleLabel,
    };
    if (compact) {
      return Row(
        children: [
          MacAppIcon(bundleName: name, size: 18, fallbackColor: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OfficeMediaExitChip(label: label, color: color, active: traffic.exit == OfficeMediaExit.node, dense: true),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '↓ ${traffic.downSpeed.speed()} · ${traffic.total.size()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TechUi.mono(context, size: 11, color: muted),
            ),
          ),
        ],
      );
    }
    return Container(
      padding: TechUi.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
      ),
      child: Row(
        children: [
          MacAppIcon(bundleName: name, size: 28, fallbackColor: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '↑ ${traffic.upSpeed.speed()}  ↓ ${traffic.downSpeed.speed()}  ·  $totalLabel ${traffic.total.size()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TechUi.mono(context, size: 11, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TechUi.trailingRow([
            OfficeMediaExitChip(label: label, color: color, active: traffic.exit == OfficeMediaExit.node),
            if (onRemove != null)
              TechUi.iconButton(
                context,
                icon: Icons.close_rounded,
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                iconColor: muted,
                onPressed: onRemove,
              ),
          ]),
        ],
      ),
    );
  }
}

class OfficeMediaExitChip extends StatelessWidget {
  const OfficeMediaExitChip({
    super.key,
    required this.label,
    required this.color,
    this.active = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool active;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      );
    }
    return TechUi.statusChip(context, label, color: color, active: active);
  }
}
