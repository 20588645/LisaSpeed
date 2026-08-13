import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/overview/sections/chain_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/dns_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/tls_tricks_page.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Prototype 高级: DNS / TLS tricks / chain boost as sections of one page.
class AdvancedOptionsPage extends HookConsumerWidget {
  const AdvancedOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final hasProfile = ref.watch(hasAnyProfileProvider).value ?? false;

    final dnsRows = dnsOptionRows(context, ref, t);
    final tlsRows = tlsTrickRows(context, ref, t);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
              eyebrow: 'Advanced',
              title: t.pages.settings.advanced.title,
              subtitle: t.pages.settings.advanced.subtitle,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Container(
                  decoration: TechUi.panelDecoration(context),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TechUi.formSectionTitle(context, t.pages.settings.dns.title, first: true),
                      for (final row in dnsRows) ...[
                        const SizedBox(height: 10),
                        row,
                      ],
                      TechUi.formSectionTitle(context, t.pages.settings.tlsTricks.title),
                      for (final row in tlsRows) ...[
                        const SizedBox(height: 10),
                        row,
                      ],
                    ],
                  ),
                ),
                if (hasProfile) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: TechUi.formSectionTitle(context, t.pages.settings.chain.title, first: true),
                  ),
                  ...chainTimelineSections(context, ref, t),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
