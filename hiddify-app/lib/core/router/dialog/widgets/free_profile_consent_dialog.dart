import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class FreeProfileConsentDialog extends HookConsumerWidget {
  const FreeProfileConsentDialog({super.key, required this.title, required this.consent});
  final String title;
  final String consent;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return TechDialog.alert(
      title: Text(title),
      content: ConstrainedBox(
        constraints: AlertDialogConst.boxConstraints,
        child: MarkdownBody(
          data: consent,
          // styleSheet: MarkdownStyleSheet(textAlign: WrapAlignment.spaceBetween),
          onTapLink: (text, href, title) => UriUtils.tryLaunch(Uri.parse(href!)),
        ),
      ),
      actions: [
        TechDialogActions.cancel(context, onPressed: () => context.pop(false), label: t.common.cancel),
        TechDialogActions.ok(context, onPressed: () => context.pop(true), label: t.common.kContinue),
      ],
    );
  }
}
