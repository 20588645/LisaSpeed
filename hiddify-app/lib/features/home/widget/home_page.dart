import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connected_at_notifier.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/host_panel/model/host_quota.dart';
import 'package:hiddify/features/host_panel/model/lisa_host_profile.dart';
import 'package:hiddify/features/host_panel/notifier/host_quota_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/features/proxy/overview/proxy_list_filter.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/stats/notifier/office_media_traffic_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hiddify/features/stats/notifier/total_traffic_notifier.dart';
import 'package:hiddify/features/stats/widget/office_media_traffic_rows.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

/// Home is a full-pane command console: connect control plus live tunnel,
/// exit, quota, subscription, and per-app modules. Extra space is filled
/// with telemetry — not empty stretched cards, and not a centered island.
class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: TechUi.pageIntroPadding,
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
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                            ),
                          ],
                        ),
                        const Gap(6),
                        Text(
                          t.pages.home.subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _HomeRefreshButton(),
                      const Gap(8),
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
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: TechUi.pageBodyPadding,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final fill = wide && constraints.maxHeight >= 520;
                    final dash = _HomeDashboard(wide: wide, fill: fill);
                    if (fill) return dash;
                    return SingleChildScrollView(child: dash);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeRefreshButton extends HookConsumerWidget {
  const _HomeRefreshButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final busy = useState(false);

    Future<void> refresh() async {
      if (busy.value) return;
      busy.value = true;
      try {
        await ref.read(hapticServiceProvider.notifier).lightImpact();
        await Future.wait([
          _refreshDelay(ref),
          ref.read(hostQuotaProvider.notifier).refreshNow(),
          if (PlatformUtils.isMacOS) ref.read(officeMediaTrafficProvider.notifier).refreshNow(),
          Future<void>.delayed(const Duration(milliseconds: 400)),
        ]);
        ref.invalidate(statsNotifierProvider);
        if (!context.mounted) return;
        ref.read(inAppNotificationControllerProvider).showSuccessToast(t.pages.home.refreshDone);
      } catch (_) {
        if (!context.mounted) return;
        ref.read(inAppNotificationControllerProvider).showErrorToast(t.pages.home.refreshFailed);
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return TechUi.ghostButton(
      context,
      label: busy.value ? '${t.pages.home.refresh}…' : t.pages.home.refresh,
      onPressed: busy.value ? null : refresh,
    );
  }
}

Future<void> _refreshDelay(WidgetRef ref) async {
  if (!ref.read(serviceRunningProvider)) return;
  await ref.read(proxyRepositoryProvider).urlTest('select').run();
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard({required this.wide, required this.fill});

  final bool wide;
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

    final isConnected = connectionStatus.valueOrNull is Connected && requiresReconnect != true;
    final isConnecting = switch (connectionStatus) {
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
      fill: fill,
    );
    final hostQuota = ref.watch(hostQuotaProvider);
    final hostPanelOn = ref.watch(Preferences.hostPanelEnabled);
    final usingLisaHost = isLisaHostProfile(ref.watch(activeProfileProvider).valueOrNull);
    final officeOn = PlatformUtils.isMacOS && ref.watch(ConfigOptions.officeMediaProxy);
    final officeApps = PlatformUtils.isMacOS ? ref.watch(ConfigOptions.officeMediaApps) : const <String>[];

    final strip = _StatusStrip(isConnected: isConnected, isConnecting: isConnecting, isDisconnecting: isDisconnecting);
    final exit = _ExitCard(isConnected: isConnected, expanded: fill);
    final traffic = _TrafficCard(isConnected: isConnected, expanded: fill);
    final quota = hostPanelOn && usingLisaHost ? _HostQuotaCard(quota: hostQuota, expanded: fill) : null;
    final profile = _ProfileCard(expanded: fill, hideTraffic: hostPanelOn && usingLisaHost);
    final tunnel = _TunnelCard(isConnected: isConnected, expanded: fill);
    final apps = PlatformUtils.isMacOS ? _AppsTrafficCard(apps: officeApps, enabled: officeOn, expanded: fill) : null;

    if (!wide) {
      return Column(
        children: [
          strip,
          const Gap(10),
          hero,
          const Gap(10),
          exit,
          const Gap(10),
          traffic,
          if (quota != null) ...[const Gap(10), quota],
          const Gap(10),
          profile,
          const Gap(10),
          tunnel,
          if (apps != null) ...[const Gap(10), apps],
        ],
      );
    }

    Widget box(Widget child) => fill ? Expanded(child: child) : child;

    final top = Row(
      crossAxisAlignment: fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: hero),
        const Gap(12),
        Expanded(flex: 6, child: Column(children: [box(exit), const Gap(10), box(traffic)])),
      ],
    );

    final bottom = Row(
      crossAxisAlignment: fill ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        if (quota != null) ...[Expanded(child: quota), const Gap(10)],
        Expanded(child: profile),
        const Gap(10),
        Expanded(child: tunnel),
        if (apps != null) ...[const Gap(10), Expanded(flex: 2, child: apps)],
      ],
    );

    if (!fill) {
      return Column(children: [strip, const Gap(10), top, const Gap(10), bottom]);
    }
    return Column(
      children: [
        strip,
        const Gap(10),
        Expanded(flex: 7, child: top),
        const Gap(10),
        Expanded(flex: 5, child: bottom),
      ],
    );
  }
}

class _HeroCard extends ConsumerWidget {
  const _HeroCard({
    required this.isConnected,
    required this.isConnecting,
    required this.isDisconnecting,
    required this.fill,
  });

  final bool isConnected;
  final bool isConnecting;
  final bool isDisconnecting;
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final mode = ref.watch(ConfigOptions.serviceMode);
    final accent = ConnectionButtonTheme.accentOf(context);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _ProfilePill(
                label: activeProfile?.name ?? t.pages.profiles.add,
                onTap: () {
                  if (activeProfile == null) {
                    ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
                  } else {
                    context.goNamed('profiles');
                  }
                },
              ),
            ),
            Gap(fill ? 4 : 8),
            const Center(child: ConnectionButton()),
            Gap(fill ? 4 : 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                subLabel,
                key: ValueKey(subLabel),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subColor),
              ),
            ),
            Gap(fill ? 8 : 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: TechUi.seg<ServiceMode>(
                  context,
                  options: ServiceMode.choices,
                  selected: mode,
                  label: (m) => m.presentShort(t),
                  onChanged: (m) => ref.read(ConfigOptions.serviceMode.notifier).update(m),
                ),
              ),
            ),
            const Gap(6),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  modeHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            if (fill) ...[
              const Gap(8),
              Expanded(child: _HeroTelemetry(isConnected: isConnected, expand: true)),
            ] else ...[
              const Gap(12),
              _HeroTelemetry(isConnected: isConnected, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroTelemetry extends ConsumerWidget {
  const _HeroTelemetry({required this.isConnected, required this.expand});

  final bool isConnected;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final up = stats.uplink.toInt();
    final down = stats.downlink.toInt();
    final connectedAt = ref.watch(connectedAtProvider);
    final conns = '${stats.connectionsIn} / ${stats.connectionsOut}';
    final top = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _MetricCell(label: t.pages.home.statsUp, value: isConnected ? '↑ ${up.speed()}' : '—'),
        ),
        const Gap(8),
        Expanded(
          child: _MetricCell(label: t.pages.home.statsDown, value: isConnected ? '↓ ${down.speed()}' : '—'),
        ),
      ],
    );
    final bottom = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _LiveDurationCell(since: isConnected ? connectedAt : null, label: t.pages.home.connDuration),
        ),
        const Gap(8),
        Expanded(
          child: _MetricCell(label: t.pages.home.statsConns, value: isConnected ? conns : '—'),
        ),
      ],
    );
    return Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (expand) Expanded(child: top) else top,
        const Gap(8),
        if (expand) Expanded(child: bottom) else bottom,
      ],
    );
  }
}

class _LiveDurationCell extends HookWidget {
  const _LiveDurationCell({required this.since, required this.label});

  final DateTime? since;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    useEffect(() {
      if (since == null) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) => tick.value++);
      return timer.cancel;
    }, [since]);
    final value = since == null ? '—' : _formatDuration(DateTime.now().difference(since!));
    return _MetricCell(label: label, value: value);
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: muted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ConnectionButtonTheme.lineOf(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 10,
            ),
          ),
          const Gap(4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TechUi.mono(context, size: 15)),
        ],
      ),
    );
  }
}

String _formatDuration(Duration elapsed) {
  final h = elapsed.inHours;
  final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class _StatusStrip extends ConsumerWidget {
  const _StatusStrip({required this.isConnected, required this.isConnecting, required this.isDisconnecting});

  final bool isConnected;
  final bool isConnecting;
  final bool isDisconnecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final mode = ref.watch(ConfigOptions.serviceMode);
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final accent = ConnectionButtonTheme.accentOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final delay = activeProxy?.urlTestDelay ?? 0;
    final protocol = activeProxy == null
        ? ''
        : (proxyProtocolLabel(proxyRemark(activeProxy), activeProxy.type) ??
            (isInjectedAutoGroup(activeProxy) ? '' : activeProxy.type));
    final ip = activeProxy?.ipinfo.ip.trim() ?? '';
    final session = stats.uplinkTotal.toInt() + stats.downlinkTotal.toInt();
    final delayText = proxyDelayLabel(
      delay,
      testing: t.pages.home.delayTesting,
      timeout: t.pages.proxies.delay.timeout,
    );

    final (stateLabel, stateColor) = isConnected
        ? (t.pages.home.stateOnline, accent)
        : isDisconnecting
        ? (t.pages.home.stateClosing, muted)
        : isConnecting
        ? (t.pages.home.stateHandshake, ConnectionButtonTheme.accent2Of(context))
        : (t.pages.home.stateIdle, muted);

    Widget cell(String label, String value, {Color? valueColor}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontSize: 10,
              ),
            ),
            const Gap(4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TechUi.mono(context, color: valueColor),
            ),
          ],
        ),
      );
    }

    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(width: 1, height: 28, color: ConnectionButtonTheme.lineOf(context)),
    );

    return Container(
      width: double.infinity,
      decoration: TechUi.panelDecoration(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          cell(t.pages.home.statsState, stateLabel, valueColor: stateColor),
          divider(),
          cell(t.pages.home.connectionMode, mode.presentShort(t)),
          divider(),
          cell(
            t.pages.home.statsProtocol,
            protocol.isEmpty ? '—' : protocol,
            valueColor: isConnected ? accent : null,
          ),
          divider(),
          cell(
            t.pages.home.delay,
            isConnected ? delayText : '—',
            valueColor: isConnected && delay > 0 && delay < 65000 ? TechUi.delayColor(context, delay) : null,
          ),
          divider(),
          cell(t.pages.home.exitIp, ip.isEmpty ? '—' : ip, valueColor: isConnected && ip.isNotEmpty ? accent : null),
          divider(),
          cell(t.pages.home.statsSession, isConnected ? session.size() : '—'),
        ],
      ),
    );
  }
}

class _ExitCard extends ConsumerWidget {
  const _ExitCard({required this.isConnected, required this.expanded});

  final bool isConnected;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final activeProxy = ref.watch(activeProxyNotifierProvider).valueOrNull;
    final accent = ConnectionButtonTheme.accentOf(context);
    final locale = ref.watch(localePreferencesProvider);
    final chinese = locale == AppLocale.zhCn || locale == AppLocale.zhTw;

    final country = activeProxy?.ipinfo.countryCode.trim() ?? '';
    final org = activeProxy?.ipinfo.org.trim() ?? '';
    final city = activeProxy?.ipinfo.city.trim() ?? '';
    final ip = activeProxy?.ipinfo.ip.trim() ?? '';
    final name = activeProxy == null
        ? '—'
        : proxyDisplayTitle(activeProxy, chinese: chinese, autoLabel: t.pages.proxies.autoSelect);
    final protocol = activeProxy == null
        ? ''
        : (proxyProtocolLabel(proxyRemark(activeProxy), activeProxy.type) ??
            (isInjectedAutoGroup(activeProxy) ? '' : activeProxy.type));
    final host = (activeProxy == null || activeProxy.isGroup) ? '' : activeProxy.host.trim();
    final port = activeProxy?.port ?? 0;
    final endpoint = host.isEmpty ? '' : (port > 0 ? '$host:$port' : host);
    final region = [if (country.isNotEmpty) country, if (city.isNotEmpty) city].join(' · ');
    final encrypted = activeProxy != null && proxyLooksEncrypted(activeProxy);

    return _SideCard(
      label: t.pages.home.statsExit,
      onTap: () => context.goNamed('proxies'),
      expanded: expanded,
      child: Column(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: expanded ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
        children: [
          Row(
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
              TechUi.latencyPill(
                context,
                activeProxy?.urlTestDelay ?? 0,
                emptyLabel: t.pages.home.delayTesting,
              ),
            ],
          ),
          const Gap(6),
          _KvRow(k: t.pages.home.statsProtocol, v: protocol.isEmpty ? '—' : protocol, dimmed: !isConnected),
          if (endpoint.isNotEmpty) ...[
            const Gap(4),
            _KvRow(k: t.pages.home.statsEndpoint, v: endpoint, dimmed: !isConnected),
          ],
          const Gap(4),
          _KvRow(k: t.pages.home.exitLine, v: region.isEmpty ? '—' : region, dimmed: !isConnected),
          const Gap(4),
          _KvRow(k: t.pages.home.statsOrg, v: org.isEmpty ? '—' : org, dimmed: !isConnected),
          const Gap(4),
          _KvRow(
            k: t.pages.home.exitIp,
            v: ip.isEmpty ? '—' : ip,
            dimmed: !isConnected,
            valueColor: isConnected && ip.isNotEmpty ? accent : null,
          ),
          const Gap(4),
          _KvRow(
            k: t.pages.home.statsEncrypt,
            v: !isConnected
                ? '—'
                : encrypted
                ? t.pages.home.encryptYes
                : t.pages.home.encryptNo,
            dimmed: !isConnected,
            valueColor: isConnected && encrypted ? accent : null,
          ),
          if (activeProxy != null && activeProxy.ipinfo.asn > 0) ...[
            const Gap(4),
            _KvRow(k: t.pages.home.statsAsn, v: 'AS${activeProxy.ipinfo.asn}', dimmed: !isConnected),
          ],
        ],
      ),
    );
  }
}

class _TrafficCard extends ConsumerWidget {
  const _TrafficCard({required this.isConnected, required this.expanded});

  final bool isConnected;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final stats = ref.watch(statsNotifierProvider).asData?.value ?? SystemInfo.create();
    final life = ref.watch(totalTrafficProvider);
    final sessionUp = stats.uplinkTotal.toInt();
    final sessionDown = stats.downlinkTotal.toInt();
    return _SideCard(
      label: t.pages.home.statsTraffic,
      expanded: expanded,
      child: Column(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: expanded ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
        children: [
          _KvRow(k: t.pages.home.statsSession, v: '${sessionUp.size()} / ${sessionDown.size()}', dimmed: !isConnected),
          const Gap(4),
          _KvRow(k: t.pages.home.statsTotal, v: (life.uplink + life.downlink).size()),
          const Gap(4),
          _KvRow(k: t.pages.home.connIn, v: '${stats.connectionsIn}', dimmed: !isConnected),
          const Gap(4),
          _KvRow(k: t.pages.home.connOut, v: '${stats.connectionsOut}', dimmed: !isConnected),
        ],
      ),
    );
  }
}

/// LisaHost panel quota: real usage billed by the hypervisor, polled from
/// the client area (independent of the app-side counters above).
class _HostQuotaCard extends ConsumerWidget {
  const _HostQuotaCard({required this.quota, required this.expanded});

  final HostQuota? quota;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final accent = ConnectionButtonTheme.accentOf(context);
    final q = quota;
    final ratio = q?.ratio ?? 0;
    final pace = q?.paceRatio();
    final overPace = pace != null && ratio > pace + 0.02;
    final barColor = ratio >= 0.9
        ? Theme.of(context).colorScheme.error
        : overPace
        ? TechUi.warnOf(context)
        : accent;
    final percentColor = q == null
        ? null
        : ratio >= 0.9
        ? Theme.of(context).colorScheme.error
        : overPace
        ? TechUi.warnOf(context)
        : accent;

    String gb(double value) =>
        value >= 1024 ? '${(value / 1024).toStringAsFixed(2)} TB' : '${value.toStringAsFixed(value < 100 ? 1 : 0)} GB';

    return _SideCard(
      label: t.pages.home.statsHostQuota,
      expanded: expanded,
      child: Column(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: expanded ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
        children: [
          _KvRow(
            k: t.pages.home.hostQuotaUsed,
            v: q == null ? t.pages.home.hostQuotaWaiting : '${gb(q.usedGb)} / ${gb(q.totalGb)}',
          ),
          const Gap(4),
          _KvRow(
            k: t.pages.home.statsPercent,
            v: q == null ? '—' : '${(ratio * 100).round()}%',
            valueColor: percentColor,
          ),
          if (pace != null) ...[const Gap(4), _KvRow(k: t.pages.home.hostQuotaPace, v: '${(pace * 100).round()}%')],
          const Gap(6),
          _QuotaProgressBar(used: ratio, pace: pace, color: barColor),
          const Gap(6),
          _KvRow(k: t.pages.home.statsExpire, v: q?.expiryDate ?? '—'),
        ],
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.expanded, required this.hideTraffic});

  final bool expanded;
  final bool hideTraffic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final nodeCount = ref.watch(proxiesOverviewNotifierProvider).asData?.value?.items.length;
    final name = profile?.name ?? '—';
    final updated = profile == null ? '—' : DateFormat('MM-dd HH:mm').format(profile.lastUpdate);
    final kind = switch (profile) {
      RemoteProfileEntity() => t.pages.profiles.tagRemote,
      LocalProfileEntity() => t.pages.profiles.tagLocal,
      null => '—',
    };
    final source = switch (profile) {
      RemoteProfileEntity(:final url) => Uri.tryParse(url)?.host ?? url,
      LocalProfileEntity() => t.pages.home.profileSourceLocal,
      null => '—',
    };

    SubscriptionInfo? info;
    if (profile is RemoteProfileEntity) info = profile.subInfo;
    final finiteTraffic = info != null && info.total > 0 && !info.total.isInfinitSize();
    final showTraffic = finiteTraffic && !hideTraffic;
    final expire = info == null
        ? null
        : info.isExpired
        ? t.components.subscriptionInfo.expired
        : DateFormat('yyyy-MM-dd').format(info.expire);

    final accent = ConnectionButtonTheme.accentOf(context);
    final barColor = (info?.ratio ?? 0) >= 0.9 ? Theme.of(context).colorScheme.error : accent;
    return _SideCard(
      label: t.pages.home.statsProfile,
      onTap: () => context.goNamed('profiles'),
      expanded: expanded,
      child: Column(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: expanded ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(6),
          _KvRow(k: t.pages.home.profileKind, v: kind),
          const Gap(4),
          _KvRow(k: t.pages.home.profileSource, v: source),
          const Gap(4),
          _KvRow(k: t.pages.home.profileUpdated, v: updated),
          const Gap(4),
          _KvRow(k: t.pages.home.profileNodes, v: nodeCount?.toString() ?? '—'),
          if (expire != null && !hideTraffic) ...[const Gap(4), _KvRow(k: t.pages.home.statsExpire, v: expire)],
          if (showTraffic) ...[
            const Gap(6),
            LinearProgressIndicator(
              value: info.ratio,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.16),
              color: barColor,
            ),
            const Gap(6),
            _KvRow(k: t.pages.home.statsUsed, v: '${info.consumption.size()} / ${info.total.size()}'),
          ],
        ],
      ),
    );
  }
}

class _TunnelCard extends ConsumerWidget {
  const _TunnelCard({required this.isConnected, required this.expanded});

  final bool isConnected;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final mode = ref.watch(ConfigOptions.serviceMode);
    final port = ref.watch(ConfigOptions.mixedPort);
    final dns = _shortDns(ref.watch(ConfigOptions.remoteDnsAddress));
    return _SideCard(
      label: t.pages.home.statsTunnel,
      onTap: () => context.goNamed('settings'),
      expanded: expanded,
      child: Column(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: expanded ? MainAxisAlignment.spaceEvenly : MainAxisAlignment.start,
        children: [
          _KvRow(k: t.pages.home.connectionMode, v: mode.presentShort(t), dimmed: !isConnected),
          const Gap(4),
          _KvRow(
            k: t.pages.home.statsTakeover,
            v: mode == ServiceMode.tun ? t.pages.home.statsOn : t.pages.home.statsOff,
            dimmed: !isConnected,
          ),
          const Gap(4),
          _KvRow(k: t.pages.home.statsDns, v: dns),
          const Gap(4),
          _KvRow(k: t.pages.home.statsPort, v: '$port'),
        ],
      ),
    );
  }
}

String _shortDns(String raw) {
  return raw.replaceFirst(RegExp(r'^(tcp|udp|tls|https|https\+local|quic)://'), '');
}

class _AppsTrafficCard extends ConsumerWidget {
  const _AppsTrafficCard({required this.apps, required this.enabled, required this.expanded});

  final List<String> apps;
  final bool enabled;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final emptyLabel = !enabled ? t.pages.home.appsOff : t.pages.home.appsEmpty;
    final body = !enabled || apps.isEmpty
        ? Align(
            alignment: Alignment.topLeft,
            child: Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
          )
        : (expanded
              ? SingleChildScrollView(child: OfficeMediaTrafficRows(apps: apps, compact: true))
              : OfficeMediaTrafficRows(apps: apps, compact: true));
    return _SideCard(
      label: t.pages.home.statsApps,
      onTap: () => context.goNamed('officeMedia'),
      expanded: expanded,
      child: body,
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.child, this.onTap, this.expanded = false});

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
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
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, height: 1),
                ),
            ],
          ),
          const Gap(8),
          if (expanded) Expanded(child: child) else child,
        ],
      ),
    );

    Widget card;
    if (onTap == null) {
      card = Container(width: double.infinity, decoration: TechUi.panelDecoration(context), child: content);
    } else {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(width: double.infinity, decoration: TechUi.panelDecoration(context), child: content),
        ),
      );
    }
    if (!expanded) return card;
    return SizedBox.expand(child: card);
  }
}

/// Used fill plus a tick at the even-pace position for this billing cycle.
class _QuotaProgressBar extends StatelessWidget {
  const _QuotaProgressBar({required this.used, required this.color, this.pace});

  final double used;
  final double? pace;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tick = Theme.of(context).colorScheme.onSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 10,
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 6,
                width: width,
                child: LinearProgressIndicator(
                  value: used,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.16),
                  color: color,
                ),
              ),
              if (pace != null)
                Positioned(
                  left: (width * pace! - 1).clamp(0.0, (width - 2).clamp(0.0, width)),
                  top: 0,
                  child: Container(
                    width: 2,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tick,
                      borderRadius: BorderRadius.circular(1),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 2)],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
