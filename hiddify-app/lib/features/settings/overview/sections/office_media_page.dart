import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/mac_app_icon.dart';
import 'package:hiddify/features/settings/widget/office_media_apps_block.dart';
import 'package:hiddify/features/stats/model/office_media_traffic.dart';
import 'package:hiddify/features/stats/notifier/office_media_traffic_notifier.dart';
import 'package:hiddify/features/stats/widget/office_media_traffic_rows.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Dedicated page for office-network per-app routing: enable, pick Mac apps,
/// and watch live exit / speed / totals.
class OfficeMediaPage extends ConsumerWidget {
  const OfficeMediaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final enabled = ref.watch(ConfigOptions.officeMediaProxy);
    final apps = ref.watch(ConfigOptions.officeMediaApps);
    final stats = ref.watch(officeMediaTrafficProvider);
    final vpnMode = ref.watch(ConfigOptions.serviceMode) == ServiceMode.tun;
    final connected = ref.watch(serviceRunningProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.pageIntro(
              context,
              title: t.pages.settings.officeMedia.title,
              subtitle: t.pages.settings.officeMedia.subtitle,
            ),
          ),
          Expanded(
            child: ListView(
              padding: TechUi.pageBodyPadding,
              children: [
                _EnablePanel(enabled: enabled),
                if (!vpnMode) ...[
                  const Gap(12),
                  _HintCard(text: t.pages.settings.officeMedia.vpnHint, warn: true),
                ] else if (enabled && !connected) ...[
                  const Gap(12),
                  _HintCard(text: t.pages.settings.officeMedia.needConnected),
                ],
                const Gap(16),
                _AppsPanel(enabled: enabled, apps: apps, stats: stats),
                const Gap(16),
                const _HowPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnablePanel extends ConsumerWidget {
  const _EnablePanel({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Container(
      decoration: TechUi.panelDecoration(context),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      child: TechUi.formSwitchRow(
        context,
        title: t.pages.settings.officeMedia.enable,
        subtitle: t.pages.settings.officeMedia.enableMsg,
        value: enabled,
        onChanged: ref.read(ConfigOptions.officeMediaProxy.notifier).update,
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? TechUi.warnOf(context) : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(warn ? Icons.info_outline_rounded : Icons.schedule_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _AppsPanel extends ConsumerWidget {
  const _AppsPanel({required this.enabled, required this.apps, required this.stats});

  final bool enabled;
  final List<String> apps;
  final Map<String, OfficeMediaAppTraffic> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final onNode = apps.where((name) {
      final exit = stats[name]?.exit;
      return exit == OfficeMediaExit.node || exit == OfficeMediaExit.mixed;
    }).length;
    final up = apps.fold<int>(0, (sum, name) => sum + (stats[name]?.upSpeed ?? 0));
    final down = apps.fold<int>(0, (sum, name) => sum + (stats[name]?.downSpeed ?? 0));

    return Container(
      decoration: TechUi.panelDecoration(context),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: TechUi.formSectionTitle(context, t.pages.settings.officeMedia.appsSection, first: true)),
              TechUi.tinyButton(
                context,
                label: t.pages.settings.general.officeMediaAppsAdd,
                onPressed: () => openOfficeMediaAppPicker(context, ref, apps),
              ),
            ],
          ),
          if (apps.isNotEmpty) ...[
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetaChip(
                  text: enabled
                      ? (onNode > 0
                            ? t.pages.settings.officeMedia.summaryOnNode(n: onNode)
                            : t.pages.settings.officeMedia.summaryIdle)
                      : t.pages.settings.officeMedia.statusOff,
                ),
                _MetaChip(text: '↑ ${up.speed()}  ↓ ${down.speed()}'),
              ],
            ),
          ],
          const Gap(12),
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                t.pages.settings.general.officeMediaAppsEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.45),
              ),
            )
          else
            Opacity(
              opacity: enabled ? 1 : 0.55,
              child: Column(
                children: [
                  for (final (i, name) in apps.indexed) ...[
                    if (i > 0) const Gap(10),
                    _AppCard(
                      name: name,
                      traffic: stats[name] ?? OfficeMediaAppTraffic.empty,
                      onRemove: () {
                        final next = [...apps]..remove(name);
                        ref.read(ConfigOptions.officeMediaApps.notifier).update(next);
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: muted.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TechUi.mono(context, size: 11, weight: FontWeight.w600, color: muted),
      ),
    );
  }
}

class _AppCard extends ConsumerWidget {
  const _AppCard({required this.name, required this.traffic, required this.onRemove});

  final String name;
  final OfficeMediaAppTraffic traffic;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = ConnectionButtonTheme.accentOf(context);
    final color = switch (traffic.exit) {
      OfficeMediaExit.node => accent,
      OfficeMediaExit.direct || OfficeMediaExit.mixed => TechUi.warnOf(context),
      OfficeMediaExit.idle => muted,
    };
    final label = switch (traffic.exit) {
      OfficeMediaExit.node => t.pages.settings.general.officeMediaExitNode,
      OfficeMediaExit.direct => t.pages.settings.general.officeMediaExitDirect,
      OfficeMediaExit.mixed => t.pages.settings.general.officeMediaExitMixed,
      OfficeMediaExit.idle => t.pages.settings.general.officeMediaExitIdle,
    };
    return Container(
      padding: TechUi.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              MacAppIcon(bundleName: name, fallbackColor: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              TechUi.trailingRow([
                OfficeMediaExitChip(label: label, color: color, active: traffic.exit == OfficeMediaExit.node),
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
          const Gap(10),
          Row(
            children: [
              Expanded(
                child: _StatCell(label: t.pages.settings.officeMedia.speedUp, value: '↑ ${traffic.upSpeed.speed()}'),
              ),
              Expanded(
                child: _StatCell(
                  label: t.pages.settings.officeMedia.speedDown,
                  value: '↓ ${traffic.downSpeed.speed()}',
                ),
              ),
              Expanded(
                child: _StatCell(label: t.pages.settings.general.officeMediaStatsTotal, value: traffic.total.size()),
              ),
            ],
          ),
          if (traffic.connections > 0) ...[
            const Gap(8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.pages.settings.officeMedia.connections(n: traffic.connections),
                style: TechUi.mono(context, size: 11, color: muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w700, letterSpacing: 0.6, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(value, style: TechUi.mono(context, size: 12, weight: FontWeight.w600)),
      ],
    );
  }
}

class _HowPanel extends ConsumerWidget {
  const _HowPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final body = Theme.of(context).textTheme.bodySmall?.copyWith(color: muted, height: 1.5);
    return Container(
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TechUi.formSectionTitle(context, t.pages.settings.officeMedia.howTitle, first: true),
          const Gap(8),
          Text(t.pages.settings.officeMedia.howBody, style: body),
          const Gap(10),
          Text(t.pages.settings.officeMedia.legendNode, style: body),
          Text(t.pages.settings.officeMedia.legendDirect, style: body),
          Text(t.pages.settings.officeMedia.legendIdle, style: body),
        ],
      ),
    );
  }
}
