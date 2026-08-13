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
import 'package:hiddify/features/host_panel/model/host_quota.dart';
import 'package:hiddify/features/host_panel/notifier/host_quota_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/total_traffic_notifier.dart';
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

    // Header and dashboard share one centered 860px cap: the add button
    // pins to the top-right of the content block, flush with the card
    // column, and the dashboard floats centered in the leftover space
    // (scrolls from the top when the window is too short).
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Row(
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
                      // Same ghost-button shell as every other page header.
                      KeyedSubtree(
                        key: const ValueKey('profile_add_button'),
                        child: TechUi.ghostButton(
                          context,
                          label: '+ ${t.pages.profiles.add}',
                          onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 20, bottom: 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: LayoutBuilder(
                          builder: (context, constraints) => _HomeDashboard(wide: constraints.maxWidth >= 680),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final hostQuota = ref.watch(hostQuotaProvider);
    final cards = [
      _ExitCard(isConnected: isConnected),
      _TrafficCard(isConnected: isConnected),
      const _NodeCard(),
      const _ProfileCard(),
      if (hostQuota != null) _HostQuotaCard(quota: hostQuota),
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

    // Prototype `.home-b-grid`: 1.15fr/1fr columns, 14px gutter, max 860px.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: IntrinsicHeight(
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
        ),
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
                const Gap(12),
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
                const Gap(16),
                TechUi.seg<ServiceMode>(
                  context,
                  options: ServiceMode.choices,
                  selected: mode,
                  label: (m) => m.presentShort(t),
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
            style: TechUi.mono(context, size: 12, weight: FontWeight.w600, color: accent),
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
          _KvRow(k: t.pages.home.exitLine, v: line(), dimmed: !isConnected),
          const Gap(8),
          _KvRow(
            k: t.pages.home.exitIp,
            v: ip.isNotEmpty ? ip : '—',
            dimmed: !isConnected,
            valueColor: isConnected && ip.isNotEmpty ? accent : null,
          ),
        ],
      ),
    );
  }
}

class _TrafficCard extends ConsumerWidget {
  const _TrafficCard({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final lifetimeTraffic = ref.watch(totalTrafficProvider);

    return _SideCard(
      label: t.pages.home.statsTraffic,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KvRow(k: t.pages.home.statsUp, v: stats.uplink.toInt().speed(), dimmed: !isConnected),
          const Gap(8),
          _KvRow(k: t.pages.home.statsDown, v: stats.downlink.toInt().speed(), dimmed: !isConnected),
          const Gap(8),
          // Lifetime counter stays lit while disconnected: unlike the live
          // rates it remains meaningful.
          _KvRow(
            k: t.pages.home.statsTotal,
            v: (lifetimeTraffic.uplink + lifetimeTraffic.downlink).size(),
          ),
        ],
      ),
    );
  }
}

/// LisaHost panel quota: real usage billed by the hypervisor, polled from
/// the client area (independent of the app-side counters above).
class _HostQuotaCard extends ConsumerWidget {
  const _HostQuotaCard({required this.quota});

  final HostQuota quota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final accent = ConnectionButtonTheme.accentOf(context);
    final ratio = quota.ratio;
    final barColor = ratio >= 0.9 ? Theme.of(context).colorScheme.error : accent;

    String gb(double value) => value >= 1024
        ? '${(value / 1024).toStringAsFixed(2)} TB'
        : '${value.toStringAsFixed(value < 100 ? 1 : 0)} GB';

    final cycle = [
      if (quota.resetDay != null) t.pages.home.hostQuotaResetDay(day: quota.resetDay!),
      if (quota.expiryDate != null) quota.expiryDate!,
    ].join(' · ');

    return _SideCard(
      label: t.pages.home.statsHostQuota,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KvRow(k: t.pages.home.hostQuotaUsed, v: '${gb(quota.usedGb)} / ${gb(quota.totalGb)}'),
          const Gap(8),
          // Same 6px usage-bar shell as the subscription rows.
          LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.16),
            color: barColor,
          ),
          if (cycle.isNotEmpty) ...[
            const Gap(8),
            _KvRow(k: t.pages.home.hostQuotaCycle, v: cycle),
          ],
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
        borderRadius: BorderRadius.circular(16),
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
  const _KvRow({required this.k, required this.v, this.valueColor, this.dimmed = false});

  final String k;
  final String v;
  final Color? valueColor;

  /// Prototype greys `.hb-v` values out until the tunnel is up.
  final bool dimmed;

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
            style: TechUi.mono(
              context,
              color: valueColor ?? (dimmed ? Theme.of(context).colorScheme.onSurfaceVariant : null),
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
