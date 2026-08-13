import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// DNS rows shared between the standalone page and the merged advanced page.
List<Widget> dnsOptionRows(BuildContext context, WidgetRef ref, Translations t) {
  return [
    ValuePreferenceWidget(
      value: ref.watch(ConfigOptions.remoteDnsAddress),
      preferences: ref.watch(ConfigOptions.remoteDnsAddress.notifier),
      title: t.pages.settings.dns.remoteDns,
    ),
    ChoicePreferenceWidget(
      selected: ref.watch(ConfigOptions.remoteDnsDomainStrategy),
      preferences: ref.watch(ConfigOptions.remoteDnsDomainStrategy.notifier),
      choices: DomainStrategy.values,
      title: t.pages.settings.dns.remoteDnsDomainStrategy,
      presentChoice: (value) => value.present(t),
    ),
    TechUi.formSwitchRow(
      context,
      title: t.pages.settings.dns.enableFakeDns,
      value: ref.watch(ConfigOptions.enableFakeDns),
      onChanged: ref.read(ConfigOptions.enableFakeDns.notifier).update,
    ),
    ValuePreferenceWidget(
      title: t.pages.settings.dns.directDns,
      value: ref.watch(ConfigOptions.directDnsAddress),
      preferences: ref.watch(ConfigOptions.directDnsAddress.notifier),
    ),
    ChoicePreferenceWidget(
      selected: ref.watch(ConfigOptions.directDnsDomainStrategy),
      preferences: ref.watch(ConfigOptions.directDnsDomainStrategy.notifier),
      choices: DomainStrategy.values,
      title: t.pages.settings.dns.directDnsDomainStrategy,
      presentChoice: (value) => value.present(t),
    ),
  ];
}

class DnsOptionsPage extends HookConsumerWidget {
  const DnsOptionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
              eyebrow: 'DNS',
              title: t.pages.settings.dns.title,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: TechUi.preferencePanel(context, children: dnsOptionRows(context, ref, t)),
          ),
        ],
      ),
    );
  }
}
