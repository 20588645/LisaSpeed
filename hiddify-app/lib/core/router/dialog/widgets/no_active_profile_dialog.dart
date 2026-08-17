import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class NoActiveProfileDialog extends HookConsumerWidget {
  const NoActiveProfileDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return TechDialog.alert(
      title: Text(t.dialogs.noActiveProfile.title),
      content: Text(t.dialogs.noActiveProfile.msg),
      actions: [
        TechDialogActions.text(
          context,
          label: t.dialogs.noActiveProfile.helpBtn.label,
          onPressed: () async {
            await UriUtils.tryLaunch(Uri.parse(t.dialogs.noActiveProfile.helpBtn.url));
          },
        ),
        TechDialogActions.ok(context, onPressed: () => context.pop(), label: t.common.ok),
      ],
    );
  }
}
