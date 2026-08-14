import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/log/data/log_data_providers.dart';
import 'package:hiddify/features/log/model/log_level.dart';
import 'package:hiddify/features/log/overview/logs_overview_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

class LogsPage extends HookConsumerWidget with PresLogger {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final state = ref.watch(logsOverviewNotifierProvider);
    final notifier = ref.watch(logsOverviewNotifierProvider.notifier);

    final debug = ref.watch(debugModeNotifierProvider);
    final pathResolver = ref.watch(logPathResolverProvider);

    final filterController = useTextEditingController(text: state.filter);

    final canShare = debug || PlatformUtils.isDesktop;

    // One-click end-to-end test: fetch the exit IP *through the proxy* and read
    // the node latency, so the user can confirm the tunnel is really passing
    // data (not just "connected"), and see where it exits.
    Future<void> runConnectivityTest() async {
      final dialog = ref.read(dialogNotifierProvider.notifier);
      final tt = t.connection.test;
      if (!ref.read(serviceRunningProvider)) {
        await dialog.showOk(tt.title, t.connection.tapToConnect);
        return;
      }
      ref.read(inAppNotificationControllerProvider).showInfoToast(tt.running);
      final result = await ref.read(proxyRepositoryProvider).getCurrentIpInfo(CancelToken()).run();
      final delay = ref.read(activeProxyNotifierProvider).valueOrNull?.urlTestDelay ?? 0;
      result.match(
        (_) => dialog.showOk(tt.title, tt.failed),
        (info) {
          final lines = <String>[
            tt.ok,
            '${tt.exitIp}: ${info.ip}${info.countryCode.isNotEmpty ? ' (${info.countryCode})' : ''}',
            if (delay > 0 && delay < 65000) '${tt.latency}: ${delay}ms',
            if ((info.org ?? '').isNotEmpty) info.org!,
          ];
          dialog.showOk(tt.title, lines.join('\n'));
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
              eyebrow: 'Diagnostics',
              title: t.pages.logs.title,
              subtitle: t.pages.logs.subtitle,
              onBack: () => context.pop(),
              actions: [
                TechUi.ghostButton(
                  context,
                  label: t.connection.test.run,
                  onPressed: runConnectivityTest,
                ),
                TechUi.ghostButton(
                  context,
                  label: state.paused ? t.common.resume : t.common.pause,
                  onPressed: state.paused ? notifier.resume : notifier.pause,
                ),
                TechUi.ghostButton(
                  context,
                  label: t.common.clear,
                  onPressed: notifier.clear,
                ),
                if (canShare)
                  MenuAnchor(
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () async {
                          await UriUtils.tryShareOrLaunchFile(
                            Uri.parse(pathResolver.coreFile().path),
                            fileOrDir: pathResolver.directory.uri,
                          );
                        },
                        child: Text(t.pages.logs.shareCoreLogs),
                      ),
                      MenuItemButton(
                        onPressed: () async {
                          await UriUtils.tryShareOrLaunchFile(
                            Uri.parse(pathResolver.appFile().path),
                            fileOrDir: pathResolver.directory.uri,
                          );
                        },
                        child: Text(t.pages.logs.shareAppLogs),
                      ),
                    ],
                    builder: (context, controller, child) => TechUi.ghostButton(
                      context,
                      label: t.common.share,
                      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Container(
                decoration: TechUi.panelDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Prototype `.log-toolbar`: filter on the left, live badge right.
                    Container(
                      decoration: BoxDecoration(
                        color: (theme.brightness == Brightness.dark
                                ? ConnectionButtonTheme.bgElevDark
                                : ConnectionButtonTheme.bgElevLight)
                            .withValues(alpha: 0.8),
                        border: Border(
                          bottom: BorderSide(color: ConnectionButtonTheme.lineOf(context)),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          Flexible(
                            child: SizedBox(
                              width: 260,
                              child: TextFormField(
                                controller: filterController,
                                onChanged: notifier.filterMessage,
                                style: theme.textTheme.bodySmall,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: t.common.filter,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          const Gap(12),
                          DropdownButton<Option<LogLevel>>(
                            value: optionOf(state.levelFilter),
                            onChanged: (v) {
                              if (v == null) return;
                              notifier.filterLevel(v.toNullable());
                            },
                            underline: const SizedBox(),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            borderRadius: BorderRadius.circular(8),
                            items: [
                              DropdownMenuItem(value: none(), child: Text(t.common.all)),
                              ...LogLevel.choices.map((e) => DropdownMenuItem(value: some(e), child: Text(e.name))),
                            ],
                          ),
                          const Spacer(),
                          _LiveBadge(paused: state.paused),
                        ],
                      ),
                    ),
                    Expanded(
                      child: switch (state.logs) {
                        AsyncData(value: final logs) => ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            // Zebra rows mirror the prototype log panel.
                            final zebra = index.isOdd
                                ? (theme.brightness == Brightness.dark
                                        ? ConnectionButtonTheme.bgElevDark
                                        : const Color(0xFFF3F7FB))
                                    .withValues(alpha: theme.brightness == Brightness.dark ? 0.45 : 0.6)
                                : Colors.transparent;
                            return Container(
                              decoration: BoxDecoration(
                                color: zebra,
                                border: Border(
                                  bottom: BorderSide(
                                    color: ConnectionButtonTheme.lineOf(context).withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 62,
                                    child: Text(
                                      log.time != null ? DateFormat('HH:mm:ss').format(log.time!) : '',
                                      style: TechUi.mono(
                                        context,
                                        size: 11.5,
                                        weight: FontWeight.w400,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const Gap(10),
                                  SizedBox(
                                    width: 78,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Builder(
                                        builder: (context) {
                                          final levelColor =
                                              log.level?.color ?? theme.colorScheme.onSurfaceVariant;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: levelColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              (log.level?.name ?? 'log').toUpperCase(),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                fontSize: 10,
                                                color: levelColor,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const Gap(10),
                                  Expanded(
                                    child: Text(
                                      extractMessage(log.message),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        AsyncError(:final error) => Center(child: Text(t.presentShortError(error))),
                        _ => const Center(child: CircularProgressIndicator()),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype `.live-badge`: pulsing accent dot + mono label.
class _LiveBadge extends HookWidget {
  const _LiveBadge({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final accent = ConnectionButtonTheme.accentOf(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final controller = useAnimationController(duration: const Duration(milliseconds: 1600));
    useEffect(() {
      if (paused) {
        controller.stop();
        controller.value = 0;
      } else {
        controller.repeat(reverse: true);
      }
      return null;
    }, [paused]);

    final color = paused ? muted : accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Opacity(
            opacity: paused ? 0.6 : 1 - 0.55 * controller.value,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const Gap(6),
        Text(
          paused ? 'paused' : 'live',
          style: TechUi.mono(context, size: 12, weight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}

String extractMessage(String message) {
  final parts = message.split(' ');
  return parts.length <= 2 ? parts.last : parts.sublist(2).join(' ');
}
