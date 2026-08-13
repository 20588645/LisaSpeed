import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/lan_sharing_tile.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class InboundOptionsPage extends HookConsumerWidget with AppLogger {
  const InboundOptionsPage({super.key});
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
              eyebrow: 'Connection',
              title: t.pages.settings.inbound.title,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: TechUi.preferencePanel(
              context,
              children: [
                TechUi.formSectionTitle(context, t.pages.settings.inbound.sectionMode, first: true),
                ChoicePreferenceWidget(
                  selected: ref.watch(ConfigOptions.serviceMode),
                  preferences: ref.watch(ConfigOptions.serviceMode.notifier),
                  choices: ServiceMode.choices,
                  title: t.pages.settings.inbound.serviceMode,
                  presentChoice: (value) => value.present(t),
                ),
                TechUi.formSwitchRow(
                  context,
                  title: t.pages.settings.inbound.strictRoute,
                  value: ref.watch(ConfigOptions.strictRoute),
                  onChanged: ref.read(ConfigOptions.strictRoute.notifier).update,
                ),
                ChoicePreferenceWidget(
                  selected: ref.watch(ConfigOptions.tunImplementation),
                  preferences: ref.watch(ConfigOptions.tunImplementation.notifier),
                  choices: TunImplementation.values,
                  title: t.pages.settings.inbound.tunImplementation,
                  presentChoice: (value) => value.name,
                ),
                TechUi.formSectionTitle(context, t.pages.settings.inbound.sectionPorts),
                ValuePreferenceWidget(
                  value: ref.watch(ConfigOptions.mixedPort),
                  preferences: ref.watch(ConfigOptions.mixedPort.notifier),
                  title: t.pages.settings.inbound.mixedPort,
                  inputToValue: int.tryParse,
                  digitsOnly: true,
                  validateInput: isPort,
                  trailing: SwitchPreferenceWidget(preference: ConfigOptions.enableMixedPort),
                ),
                if (PlatformUtils.isLinux)
                  ValuePreferenceWidget(
                    value: ref.watch(ConfigOptions.tproxyPort),
                    preferences: ref.watch(ConfigOptions.tproxyPort.notifier),
                    title: t.pages.settings.inbound.tproxyPort,
                    inputToValue: int.tryParse,
                    digitsOnly: true,
                    validateInput: isPort,
                    trailing: SwitchPreferenceWidget(preference: ConfigOptions.enableTproxyPort),
                  ),
                if (PlatformUtils.isLinux || PlatformUtils.isMacOS)
                  ValuePreferenceWidget(
                    value: ref.watch(ConfigOptions.redirectPort),
                    preferences: ref.watch(ConfigOptions.redirectPort.notifier),
                    title: t.pages.settings.inbound.redirectPort,
                    inputToValue: int.tryParse,
                    digitsOnly: true,
                    validateInput: isPort,
                    trailing: SwitchPreferenceWidget(preference: ConfigOptions.enableRedirectPort),
                  ),
                ValuePreferenceWidget(
                  value: ref.watch(ConfigOptions.directPort),
                  preferences: ref.watch(ConfigOptions.directPort.notifier),
                  title: t.pages.settings.inbound.directPort,
                  inputToValue: int.tryParse,
                  digitsOnly: true,
                  validateInput: isPort,
                  trailing: SwitchPreferenceWidget(preference: ConfigOptions.enableDirectPort),
                ),
                TechUi.formSectionTitle(context, t.pages.settings.inbound.sectionSharing),
                const LanSharingPreferenceWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
