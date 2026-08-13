import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LanSharingPreferenceWidget extends HookConsumerWidget {
  const LanSharingPreferenceWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    Future<String?> getSharingLink() async {
      final ipResult = await ref.read(hiddifyCoreServiceProvider).getLANIP().run();
      final ip = ipResult.fold((_) => null, (r) => r.ip);
      if (ip == null) {
        ref.read(inAppNotificationControllerProvider).showErrorToast(t.pages.settings.inbound.lanIPError);
        return null;
      }
      final port = ref.read(ConfigOptions.mixedPort);
      final password = ref.read(ConfigOptions.lanSharingPassword);
      if (password.isEmpty) {
        return 'socks://$ip:$port';
      } else {
        return 'socks://hiddify:$password@$ip:$port';
      }
    }

    Future<void> editPassword() async {
      final inputValue = await ref
          .read(dialogNotifierProvider.notifier)
          .showSettingInput(
            title: t.pages.settings.inbound.lanSharingPassword,
            initialValue: ref.read(ConfigOptions.lanSharingPassword),
            onReset: ref.read(ConfigOptions.lanSharingPassword.notifier).reset,
          );
      if (inputValue != null) {
        await ref.read(ConfigOptions.lanSharingPassword.notifier).update(inputValue);
      }
    }

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: TechUi.formRowDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: editPassword,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.pages.settings.inbound.lanSharing, style: theme.textTheme.bodyMedium),
                            const Gap(2),
                            Text(
                              ref.watch(ConfigOptions.lanSharingPassword).isEmpty
                                  ? t.pages.settings.inbound.lanSharingPasswordNotSet
                                  : ref.watch(ConfigOptions.lanSharingPassword),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(8),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: ref.watch(ConfigOptions.allowConnectionFromLan),
                        onChanged: ref.read(ConfigOptions.allowConnectionFromLan.notifier).update,
                      ),
                    ),
                  ],
                ),
                if (ref.watch(ConfigOptions.allowConnectionFromLan))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        TechUi.tinyButton(
                          context,
                          label: t.pages.settings.inbound.copyLink,
                          onPressed: () async {
                            final link = await getSharingLink();
                            if (link != null) {
                              await Clipboard.setData(ClipboardData(text: link));
                              ref
                                  .read(inAppNotificationControllerProvider)
                                  .showSuccessToast(t.common.msg.export.clipboard.success);
                            }
                          },
                        ),
                        const Gap(8),
                        TechUi.tinyButton(
                          context,
                          label: t.pages.settings.inbound.qrCode,
                          onPressed: () async {
                            final link = await getSharingLink();
                            if (link != null) {
                              final qrLink = '#profile-title: LAN only\n$link#LAN only';
                              await ref.read(dialogNotifierProvider.notifier).showQrCode(qrLink, message: link);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
