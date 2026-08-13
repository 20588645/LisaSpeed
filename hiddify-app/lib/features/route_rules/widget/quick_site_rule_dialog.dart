import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_dialog.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/config/route_rule.pb.dart';
import 'package:hiddify/utils/custom_text_form_field.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// One-field self-service rule: paste a URL or domain, pick 代理/直连/拦截,
/// and a domain-suffix rule lands at the top of the routing list.
class QuickSiteRuleDialog extends ConsumerStatefulWidget {
  const QuickSiteRuleDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => const QuickSiteRuleDialog(),
    );
  }

  @override
  ConsumerState<QuickSiteRuleDialog> createState() => _QuickSiteRuleDialogState();
}

class _QuickSiteRuleDialogState extends ConsumerState<QuickSiteRuleDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Outbound _outbound = Outbound.proxy;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Accepts `youtube.com`, `www.x.com/foo`, or a full URL; returns the bare
  /// registrable host (leading `www.` stripped), or null when unusable.
  static String? parseHost(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    if (text.contains('://')) {
      final host = Uri.tryParse(text)?.host ?? '';
      text = host;
    } else {
      text = text.split('/').first.split('?').first;
      // Strip a stray port or userinfo if someone pasted host:port.
      text = text.split('@').last.split(':').first;
    }
    if (text.startsWith('www.')) text = text.substring(4);
    final valid = RegExp(r'^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$');
    return valid.hasMatch(text) ? text.toLowerCase() : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final outboundLabels = t.pages.settings.routing.routeRule.rule.outbound;

    return TechDialog(
      title: t.pages.settings.routing.quickRule.title,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.pages.settings.routing.quickRule.hint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Gap(14),
            CustomTextFormField(
              maxLines: 1,
              controller: _controller,
              label: t.pages.settings.routing.quickRule.inputLabel,
              hint: t.pages.settings.routing.quickRule.inputHint,
              validator: (value) =>
                  parseHost(value ?? '') == null ? t.pages.settings.routing.quickRule.invalid : null,
            ),
            const Gap(14),
            Text(
              t.pages.settings.routing.quickRule.action,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const Gap(8),
            TechUi.seg<Outbound>(
              context,
              options: const [Outbound.proxy, Outbound.direct, Outbound.block],
              selected: _outbound,
              label: (o) => outboundLabels[o.name] ?? o.name,
              onChanged: (o) => setState(() => _outbound = o),
            ),
          ],
        ),
      ),
      actions: [
        TechDialogActions.cancel(context, onPressed: () => Navigator.of(context).maybePop()),
        TechDialogActions.ok(
          context,
          label: t.common.add,
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final host = parseHost(_controller.text)!;
            final navigator = Navigator.of(context);
            await ref
                .read(rulesNotifierProvider.notifier)
                .addRuleFirst(Rule(name: host, outbound: _outbound, domainSuffixes: [host]));
            if (mounted && navigator.canPop()) navigator.pop();
          },
        ),
      ],
    );
  }
}
