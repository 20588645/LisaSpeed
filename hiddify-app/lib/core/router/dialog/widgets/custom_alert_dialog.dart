import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CustomAlertDialog extends HookConsumerWidget {
  const CustomAlertDialog({super.key, this.title, required this.message});

  final String? title;
  final String message;

  factory CustomAlertDialog.fromErr(({String type, String? message}) err) =>
      CustomAlertDialog(title: err.message == null ? null : err.type, message: err.message ?? err.type);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return TechDialog(
      title: title,
      icon: Icons.info_outline_rounded,
      content: Text(message, textDirection: TextDirection.ltr),
      actions: [
        TechDialogActions.ok(context, onPressed: () => context.pop(), label: t.common.ok),
      ],
    );
  }
}
