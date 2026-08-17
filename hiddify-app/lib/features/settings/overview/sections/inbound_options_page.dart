import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
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
              title: t.pages.settings.inbound.title,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: TechUi.preferencePanel(
              context,
              children: [
                // Daily-driver options only; deep networking knobs (strict
                // route, TUN implementation, extra ports…) live in 高级.
                TechUi.formSectionTitle(context, t.pages.settings.inbound.sectionMode, first: true),
                ChoicePreferenceWidget(
                  selected: ref.watch(ConfigOptions.serviceMode),
                  preferences: ref.watch(ConfigOptions.serviceMode.notifier),
                  choices: ServiceMode.choices,
                  title: t.pages.settings.inbound.serviceMode,
                  presentChoice: (value) => value.present(t),
                ),
                TechUi.formSectionTitle(context, t.connection.watchdog.section),
                TechUi.formSwitchRow(
                  context,
                  title: t.connection.watchdog.autoReconnect,
                  subtitle: t.connection.watchdog.autoReconnectMsg,
                  value: ref.watch(Preferences.autoReconnectOnStall),
                  onChanged: ref.read(Preferences.autoReconnectOnStall.notifier).update,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
