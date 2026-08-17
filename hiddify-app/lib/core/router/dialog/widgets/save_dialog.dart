import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SaveDialog extends HookConsumerWidget {
  const SaveDialog({super.key, required this.title, required this.description});
  final String title;
  final String description;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return TechDialog.alert(
      title: Text(title),
      content: ConstrainedBox(constraints: AlertDialogConst.boxConstraints, child: Text(description)),
      actions: [
        TechDialogActions.text(context, label: t.common.discard, onPressed: () => context.pop(false)),
        TechDialogActions.ok(context, label: t.common.save, onPressed: () => context.pop(true)),
      ],
    );
  }
}
