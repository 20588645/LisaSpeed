import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/features/app_update/model/remote_version_entity.dart';
import 'package:hiddify/features/app_update/notifier/app_update_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NewVersionDialog extends HookConsumerWidget with PresLogger {
  NewVersionDialog(this.currentVersion, this.newVersion, {super.key, this.canIgnore = true});

  final String currentVersion;
  final RemoteVersionEntity newVersion;
  final bool canIgnore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final accent = ConnectionButtonTheme.accentOf(context);

    return TechDialog(
      title: t.dialogs.newVersion.title,
      icon: Icons.system_update_alt_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dialogs.newVersion.msg),
          const Gap(12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: t.dialogs.newVersion.currentVersion, style: theme.textTheme.bodySmall),
                TextSpan(
                  text: currentVersion,
                  style: theme.textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Gap(4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: t.dialogs.newVersion.newVersion, style: theme.textTheme.bodySmall),
                TextSpan(
                  text: newVersion.presentVersion,
                  style: theme.textTheme.labelMedium?.copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (canIgnore)
          TechDialogActions.text(
            context,
            label: t.common.ignore,
            onPressed: () async {
              await ref.read(appUpdateNotifierProvider.notifier).ignoreRelease(newVersion);
              if (context.mounted) context.pop();
            },
          ),
        TechDialogActions.cancel(context, onPressed: context.pop, label: t.common.later),
        TechDialogActions.ok(
          context,
          label: t.dialogs.newVersion.updateNow,
          onPressed: () async {
            await UriUtils.tryLaunch(Uri.parse(newVersion.url));
          },
        ),
      ],
    );
  }
}
