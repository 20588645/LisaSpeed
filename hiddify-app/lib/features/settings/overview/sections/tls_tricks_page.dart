import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/optional_range.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

String _presentFragmentPackets(TranslationsEn t, String value) => switch (value) {
  "tlshello" => t.pages.settings.tlsTricks.packetsTlsHello,
  "1-1" => t.pages.settings.tlsTricks.packets1_1,
  "1-2" => t.pages.settings.tlsTricks.packets1_2,
  "1-3" => t.pages.settings.tlsTricks.packets1_3,
  "1-4" => t.pages.settings.tlsTricks.packets1_4,
  "1-5" => t.pages.settings.tlsTricks.packets1_5,
  _ => value,
};

/// TLS-trick rows shared between the standalone page and the merged advanced page.
List<Widget> tlsTrickRows(BuildContext context, WidgetRef ref, Translations t) {
  final canChangeOption = ref.watch(ConfigOptions.enableTlsFragment);
  return [
    TechUi.formSwitchRow(
      context,
      title: t.pages.settings.tlsTricks.enable,
      value: ref.watch(ConfigOptions.enableTlsFragment),
      onChanged: ref.read(ConfigOptions.enableTlsFragment.notifier).update,
    ),
    ChoicePreferenceWidget(
      selected: ref.watch(ConfigOptions.fragmentPackets),
      preferences: ref.watch(ConfigOptions.fragmentPackets.notifier),
      choices: const ["tlshello", "1-1", "1-2", "1-3", "1-4", "1-5"],
      title: t.pages.settings.tlsTricks.packets,
      presentChoice: (value) => _presentFragmentPackets(t, value),
      enabled: canChangeOption,
    ),
    ValuePreferenceWidget(
      value: ref.watch(ConfigOptions.tlsFragmentSize),
      preferences: ref.watch(ConfigOptions.tlsFragmentSize.notifier),
      title: t.pages.settings.tlsTricks.size,
      inputToValue: OptionalRange.tryParse,
      presentValue: (value) => value.present(t),
      formatInputValue: (value) => value.format(),
      enabled: canChangeOption,
    ),
    ValuePreferenceWidget(
      value: ref.watch(ConfigOptions.tlsFragmentSleep),
      preferences: ref.watch(ConfigOptions.tlsFragmentSleep.notifier),
      title: t.pages.settings.tlsTricks.sleep,
      inputToValue: OptionalRange.tryParse,
      presentValue: (value) => value.present(t),
      formatInputValue: (value) => value.format(),
      enabled: canChangeOption,
    ),
    TechUi.formSwitchRow(
      context,
      title: t.pages.settings.tlsTricks.mixedSniCase.enable,
      value: ref.watch(ConfigOptions.enableTlsMixedSniCase),
      onChanged: canChangeOption ? ref.read(ConfigOptions.enableTlsMixedSniCase.notifier).update : null,
    ),
    TechUi.formSwitchRow(
      context,
      title: t.pages.settings.tlsTricks.padding.enable,
      value: ref.watch(ConfigOptions.enableTlsPadding),
      onChanged: canChangeOption ? ref.read(ConfigOptions.enableTlsPadding.notifier).update : null,
    ),
    ValuePreferenceWidget(
      value: ref.watch(ConfigOptions.tlsPaddingSize),
      preferences: ref.watch(ConfigOptions.tlsPaddingSize.notifier),
      title: t.pages.settings.tlsTricks.padding.size,
      inputToValue: OptionalRange.tryParse,
      presentValue: (value) => value.format(),
      formatInputValue: (value) => value.format(),
      enabled: canChangeOption,
    ),
  ];
}

class TlsTricksPage extends HookConsumerWidget {
  const TlsTricksPage({super.key});

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
              title: t.pages.settings.tlsTricks.title,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: TechUi.preferencePanel(context, children: tlsTrickRows(context, ref, t)),
          ),
        ],
      ),
    );
  }
}
