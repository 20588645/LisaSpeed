import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConfirmationDialog extends HookConsumerWidget {
  const ConfirmationDialog({super.key, required this.title, required this.message, this.icon, this.positiveBtnTxt});
  final String title;
  final String message;
  final IconData? icon;
  final String? positiveBtnTxt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return TechDialog(
      title: title,
      icon: icon ?? Icons.help_outline_rounded,
      content: Text(message),
      actions: [
        TechDialogActions.cancel(context, onPressed: () => context.pop(false), label: t.common.cancel),
        TechDialogActions.ok(context, onPressed: () => context.pop(true), label: positiveBtnTxt ?? t.common.ok),
      ],
    );
  }
}
