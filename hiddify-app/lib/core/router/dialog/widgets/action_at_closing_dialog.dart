import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/actions_at_closing.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ActionsAtClosingDialog extends HookConsumerWidget {
  const ActionsAtClosingDialog({super.key, required this.selected});
  final ActionsAtClosing selected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return TechDialog(
      title: t.pages.settings.general.actionAtClosing,
      icon: Icons.logout_rounded,
      scrollable: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: ActionsAtClosing.values
            .map(
              (e) => RadioListTile(title: Text(e.present(t)), value: e, groupValue: selected, onChanged: context.pop),
            )
            .toList(),
      ),
      actions: [TechDialogActions.cancel(context, onPressed: () => context.pop(), label: t.common.cancel)],
    );
  }
}
