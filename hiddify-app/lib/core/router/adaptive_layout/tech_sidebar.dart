import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/total_traffic_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Prototype-matching left rail: brand, labeled nav, traffic/mode footer.
class TechSidebar extends ConsumerWidget {
  const TechSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<({IconData icon, String label})> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final accent = ConnectionButtonTheme.accentOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final elev = isDark ? ConnectionButtonTheme.bgElevDark : ConnectionButtonTheme.bgElevLight;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final lifetimeTraffic = ref.watch(totalTrafficProvider);
    final mode = ref.watch(ConfigOptions.serviceMode);

    return Container(
      width: 216,
      decoration: BoxDecoration(
        color: elev,
        border: Border(
          right: BorderSide(color: ConnectionButtonTheme.lineOf(context)),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: isDark ? 0.06 : 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 18),
            child: Row(
              children: [
                TechUi.logoMark(size: 42),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.common.appTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        t.pages.home.sidebarTag,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const Gap(4),
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final selected = index == selectedIndex;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelected(index),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          Icon(
                            dest.icon,
                            size: 18,
                            color: selected ? accent : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const Gap(12),
                          Text(
                            dest.label,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ConnectionButtonTheme.lineOf(context))),
            ),
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: accent.withValues(alpha: 0.06),
                border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
              ),
              child: Column(
                children: [
                  _TrafficRow(label: t.pages.home.statsUp, value: '↑ ${stats.uplink.toInt().speed()}'),
                  const Gap(8),
                  _TrafficRow(label: t.pages.home.statsDown, value: '↓ ${stats.downlink.toInt().speed()}'),
                  const Gap(8),
                  _TrafficRow(
                    label: t.pages.home.statsTotal,
                    value: (lifetimeTraffic.uplink + lifetimeTraffic.downlink).size(),
                  ),
                  const Gap(8),
                  _TrafficRow(label: t.pages.home.connectionMode, value: mode.presentShort(t)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficRow extends StatelessWidget {
  const _TrafficRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
