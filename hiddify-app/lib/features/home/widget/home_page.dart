import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Home layout mirrors `prototype/tech` page-home.
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.common.appTitle,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const Gap(8),
                              const AppVersionLabel(),
                            ],
                          ),
                          const Gap(6),
                          Text(
                            t.pages.home.subtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      key: const ValueKey('profile_add_button'),
                      onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        side: BorderSide(color: ConnectionButtonTheme.lineOf(context)),
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                      ),
                      child: Text('+ ${t.pages.profiles.add}'),
                    ),
                  ],
                ),
                const Gap(28),
                const Center(child: _HomeStage()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();
    final accent = ConnectionButtonTheme.accentOf(context);

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _HomeStage extends ConsumerWidget {
  const _HomeStage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final mode = ref.watch(ConfigOptions.serviceMode);
    final accent = ConnectionButtonTheme.accentOf(context);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;

    String exitLabel() {
      if (activeProxy == null) return '—';
      final country = activeProxy.ipinfo.countryCode.trim();
      final org = activeProxy.ipinfo.org.trim();
      if (country.isNotEmpty && org.isNotEmpty) {
        final shortOrg = org.length > 12 ? '${org.substring(0, 12)}…' : org;
        return '$country · $shortOrg';
      }
      if (country.isNotEmpty) return country;
      if (activeProxy.tagDisplay.isNotEmpty) return activeProxy.tagDisplay;
      return '—';
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Column(
        children: [
          _ProfilePill(
            label: activeProfile?.name ?? t.pages.profiles.add,
            onTap: () {
              if (activeProfile == null) {
                ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
              } else {
                context.goNamed('profiles');
              }
            },
          ),
          const Gap(18),
          const ConnectionButton(),
          const ActiveProxyDelayIndicator(),
          const Gap(18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: TechUi.panelDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      t.pages.home.connectionMode.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${t.pages.home.currentMode} ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextSpan(
                            text: mode.presentShort(t),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(10),
                _ModeSeg(
                  selected: mode,
                  labels: {
                    for (final m in ServiceMode.choices) m: m.presentShort(t),
                  },
                  onChanged: (m) => ref.read(ConfigOptions.serviceMode.notifier).update(m),
                ),
              ],
            ),
          ),
          const Gap(16),
          Container(
            decoration: TechUi.panelDecoration(context),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _HomeStat(label: t.pages.home.statsLive, value: stats.downlink.toInt().speed()),
                  VerticalDivider(width: 1, thickness: 1, color: ConnectionButtonTheme.lineOf(context)),
                  _HomeStat(label: t.pages.home.statsTotal, value: stats.downlinkTotal.toInt().size()),
                  VerticalDivider(width: 1, thickness: 1, color: ConnectionButtonTheme.lineOf(context)),
                  _HomeStat(label: t.pages.home.statsExit, value: exitLabel()),
                ],
              ),
            ),
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.goNamed('proxies'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                side: BorderSide(
                  color: ConnectionButtonTheme.lineOf(context),
                  style: BorderStyle.solid,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
              ),
              child: Text(
                t.pages.home.openNodes,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: ConnectionButtonTheme.panelOf(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.55), blurRadius: 10)],
                ),
              ),
              const Gap(8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const Gap(6),
              Text(
                '›',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSeg extends StatelessWidget {
  const _ModeSeg({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  final ServiceMode selected;
  final Map<ServiceMode, String> labels;
  final ValueChanged<ServiceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final line = ConnectionButtonTheme.lineOf(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            if (entry.key != labels.keys.first)
              Container(width: 1, height: 42, color: line),
            Expanded(
              child: Material(
                color: entry.key == selected ? accent : Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(entry.key),
                  child: SizedBox(
                    height: 42,
                    child: Center(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: entry.key == selected
                              ? const Color(0xFF041016)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeStat extends StatelessWidget {
  const _HomeStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
            const Gap(4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
