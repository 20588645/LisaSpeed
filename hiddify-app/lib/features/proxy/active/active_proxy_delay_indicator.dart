import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ActiveProxyDelayIndicator extends HookConsumerWidget with InfraLogger {
  const ActiveProxyDelayIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connection = ref.watch(connectionNotifierProvider).valueOrNull;
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);

    if (connection is! Connected || activeProxy is! AsyncData) {
      return const SizedBox(height: 8);
    }

    final delay = activeProxy.value!.urlTestDelay;
    final timeout = delay > 65000;
    final testing = delay <= 0;

    return Center(
      child: InkWell(
        onTap: () async {
          try {
            await ref.read(activeProxyNotifierProvider.notifier).urlTest("");
          } catch (e) {
            loggy.error("Error during URL test: $e");
          }
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: (timeout ? theme.colorScheme.error : accent).withValues(alpha: 0.12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.pages.home.delay,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: timeout ? theme.colorScheme.error : accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(8),
              Text(
                testing
                    ? '…'
                    : timeout
                        ? t.common.timeout
                        : '$delay ms',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: timeout ? theme.colorScheme.error : accent,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
