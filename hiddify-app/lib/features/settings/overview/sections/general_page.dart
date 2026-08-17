import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class GeneralPage extends HookConsumerWidget {
  const GeneralPage({super.key});
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
              title: t.pages.settings.general.title,
              onBack: () => context.pop(),
            ),
          ),
          Expanded(
            child: TechUi.preferencePanel(
              context,
              children: [
                TechUi.formSectionTitle(context, t.pages.settings.general.sectionAppearance, first: true),
                const LocalePrefTile(),
                const AppearancePrefBlock(),
                TechUi.formSectionTitle(context, t.pages.settings.general.sectionStartup),
                if (PlatformUtils.isDesktop) ...[
                  const ClosingPrefTile(),
                  TechUi.formSwitchRow(
                    context,
                    title: t.pages.settings.general.autoStart,
                    value: ref.watch(autoStartNotifierProvider).asData!.value,
                    onChanged: (value) async => value
                        ? await ref.read(autoStartNotifierProvider.notifier).enable()
                        : await ref.read(autoStartNotifierProvider.notifier).disable(),
                  ),
                  TechUi.formSwitchRow(
                    context,
                    title: t.pages.settings.general.silentStart,
                    value: ref.watch(Preferences.silentStart),
                    onChanged: ref.read(Preferences.silentStart.notifier).update,
                  ),
                  if (PlatformUtils.isMacOS)
                    TechUi.formSwitchRow(
                      context,
                      title: t.pages.settings.general.trayLiveSpeed,
                      subtitle: t.pages.settings.general.trayLiveSpeedMsg,
                      value: ref.watch(Preferences.showTraySpeed),
                      onChanged: ref.read(Preferences.showTraySpeed.notifier).update,
                    ),
                ],
                if (PlatformUtils.isAndroid) ...[
                  TechUi.formSwitchRow(
                    context,
                    title: t.pages.settings.general.dynamicNotification,
                    value: ref.watch(Preferences.dynamicNotification),
                    onChanged: ref.read(Preferences.dynamicNotification.notifier).update,
                  ),
                  TechUi.formSwitchRow(
                    context,
                    title: t.pages.settings.general.hapticFeedback,
                    value: ref.watch(hapticServiceProvider),
                    onChanged: ref.read(hapticServiceProvider.notifier).updatePreference,
                  ),
                  const BatteryOptimizationWidget(),
                ],
                TechUi.formSectionTitle(context, t.pages.settings.general.sectionHostPanel),
                TechUi.formSwitchRow(
                  context,
                  title: t.pages.settings.general.hostPanelEnabled,
                  subtitle: t.pages.settings.general.hostPanelEnabledMsg,
                  value: ref.watch(Preferences.hostPanelEnabled),
                  onChanged: ref.read(Preferences.hostPanelEnabled.notifier).update,
                ),
                ValuePreferenceWidget<String>(
                  value: ref.watch(Preferences.hostPanelEmail),
                  preferences: ref.watch(Preferences.hostPanelEmail.notifier),
                  title: t.pages.settings.general.hostPanelEmail,
                  presentValue: (value) => value.isEmpty ? '—' : value,
                ),
                ValuePreferenceWidget<String>(
                  value: ref.watch(Preferences.hostPanelPassword),
                  preferences: ref.watch(Preferences.hostPanelPassword.notifier),
                  title: t.pages.settings.general.hostPanelPassword,
                  presentValue: (value) => value.isEmpty ? '—' : '••••••••',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
