import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connected_at_notifier.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/number_formatters.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Home mirrors `prototype/tech` page-home-b: a dashboard split with the
/// connect hero card on the left and exit/traffic/node/subscription cards
/// on the right (stacking vertically on narrow windows).
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
            constraints: const BoxConstraints(maxWidth: 920),
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
                const Gap(20),
                LayoutBuilder(
                  builder: (context, constraints) => _HomeDashboard(wide: constraints.maxWidth >= 680),
                ),
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

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;
    final delay = activeProxy?.urlTestDelay ?? 0;

    final isConnected = connectionStatus.valueOrNull is Connected &&
        requiresReconnect != true &&
        delay > 0 &&
        delay < 65000;
    final isConnecting = switch (connectionStatus) {
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => true,
      AsyncLoading() => true,
      AsyncData(value: Connecting()) => true,
      AsyncData(value: Disconnecting()) => true,
      _ => false,
    };
    final isDisconnecting = connectionStatus.valueOrNull is Disconnecting;

    final hero = _HeroCard(
      isConnected: isConnected,
      isConnecting: isConnecting,
      isDisconnecting: isDisconnecting,
    );
    final cards = [
      _ExitCard(isConnected: isConnected),
      const _TrafficCard(),
      const _NodeCard(),
      const _ProfileCard(),
    ];

    if (!wide) {
      return Column(
        children: [
          hero,
          const Gap(12),
          for (final (i, card) in cards.indexed) ...[
            if (i > 0) const Gap(12),
            card,
          ],
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 23, child: hero),
          const Gap(14),
          Expanded(
            flex: 20,
            child: Column(
              children: [
                for (final (i, card) in cards.indexed) ...[
                  if (i > 0) const Gap(12),
                  Expanded(child: card),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.isConnected,
    required this.isConnecting,
    required this.isDisconnecting,
  });

  final bool isConnected;
  final bool isConnecting;
  final bool isDisconnecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final mode = ref.watch(ConfigOptions.serviceMode);
    final accent = ConnectionButtonTheme.accentOf(context);
    final accent2 = ConnectionButtonTheme.accent2Of(context);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final connectedAt = ref.watch(connectedAtProvider);

    final subLabel = isConnected
        ? t.pages.home.connSubConnected
        : isDisconnecting
            ? t.pages.home.connSubDisconnecting
            : isConnecting
                ? t.pages.home.connSubConnecting
                : t.pages.home.connSubIdle;
    final subColor = isConnected
        ? Color.lerp(accent, Theme.of(context).colorScheme.onSurfaceVariant, 0.45)!
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final modeHint = switch (mode) {
      ServiceMode.proxy => t.pages.home.modeHintProxy,
      ServiceMode.systemProxy => t.pages.home.modeHintSystem,
      ServiceMode.tun => t.pages.home.modeHintVpn,
    };

    return Container(
      decoration: TechUi.panelDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Top accent light bar, mirrors the prototype's connected glow line.
          Positioned(
            top: 0,
            left: 44,
            right: 44,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 450),
              opacity: isConnected ? 0.9 : 0,
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0),
                      accent,
                      accent2,
                      accent2.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.32, 0.68, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const Gap(14),
                const ConnectionButton(),
                const Gap(6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    subLabel,
                    key: ValueKey(subLabel),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subColor),
                  ),
                ),
                if (isConnected && connectedAt != null) ...[
                  const Gap(10),
                  _DurationChip(since: connectedAt, label: t.pages.home.connDuration),
                ],
                const Gap(18),
                _ModeSeg(
                  selected: mode,
                  labels: {
                    for (final m in ServiceMode.choices) m: m.presentShort(t),
                  },
                  onChanged: (m) => ref.read(ConfigOptions.serviceMode.notifier).update(m),
                ),
                const Gap(8),
                Text(
                  modeHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends HookWidget {
  const _DurationChip({required this.since, required this.label});

  final DateTime since;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
      return timer.cancel;
    }, [since]);

    final elapsed = DateTime.now().difference(since);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final value = h > 0 ? '$h:$m:$s' : '$m:$s';

    final accent = ConnectionButtonTheme.accentOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(6),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitCard extends ConsumerWidget {
  const _ExitCard({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final accent = ConnectionButtonTheme.accentOf(context);

    String line() {
      if (activeProxy == null) return '—';
      final country = activeProxy.ipinfo.countryCode.trim();
      final org = activeProxy.ipinfo.org.trim();
      if (country.isNotEmpty && org.isNotEmpty) return '$country · $org';
      if (country.isNotEmpty) return country;
      if (activeProxy.tagDisplay.isNotEmpty) return activeProxy.tagDisplay;
      return '—';
    }

    final ip = activeProxy?.ipinfo.ip.trim() ?? '';

    return _SideCard(
      label: t.pages.home.statsExit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KvRow(k: t.pages.home.exitLine, v: line()),
          const Gap(8),
          _KvRow(
            k: t.pages.home.exitIp,
            v: ip.isNotEmpty ? ip : '—',
            valueColor: isConnected && ip.isNotEmpty ? accent : null,
          ),
        ],
      ),
    );
  }
}

class _TrafficCard extends ConsumerWidget {
  const _TrafficCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();

    return _SideCard(
      label: t.pages.home.statsTraffic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KvRow(k: t.pages.home.statsUp, v: stats.uplink.toInt().speed()),
          const Gap(8),
          _KvRow(k: t.pages.home.statsDown, v: stats.downlink.toInt().speed()),
          const Gap(8),
          _KvRow(k: t.pages.home.statsTotal, v: (stats.uplinkTotal + stats.downlinkTotal).toInt().size()),
        ],
      ),
    );
  }
}

class _NodeCard extends ConsumerWidget {
  const _NodeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final name = activeProxy?.tagDisplay.isNotEmpty ?? false
        ? activeProxy!.tagDisplay
        : activeProxy?.tag ?? '—';

    return _SideCard(
      label: t.pages.home.currentNode,
      onTap: () => context.goNamed('proxies'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const Gap(10),
          TechUi.latencyPill(context, activeProxy?.urlTestDelay ?? 0),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;

    return _SideCard(
      label: t.pages.profiles.title,
      onTap: () {
        if (activeProfile == null) {
          ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
        } else {
          context.goNamed('profiles');
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Text(
              activeProfile?.name ?? t.pages.profiles.add,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (activeProfile != null) ...[
            const Gap(10),
            Text(
              '${t.pages.home.profileUpdated} ${DateFormat('MM-dd HH:mm').format(activeProfile.lastUpdate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.child, this.onTap});

  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTap != null)
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
          const Gap(10),
          child,
        ],
      ),
    );

    if (onTap == null) {
      return Container(
        width: double.infinity,
        decoration: TechUi.panelDecoration(context),
        child: content,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: double.infinity,
          decoration: TechUi.panelDecoration(context),
          child: content,
        ),
      ),
    );
  }
}

class _KvRow extends StatelessWidget {
  const _KvRow({required this.k, required this.v, this.valueColor});

  final String k;
  final String v;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          k,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const Gap(10),
        Expanded(
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
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
