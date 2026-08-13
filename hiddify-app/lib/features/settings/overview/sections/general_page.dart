import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/log/model/log_level.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:humanizer/humanizer.dart';

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
              eyebrow: 'General',
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
                const _AppearanceBlock(),
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
                TechUi.formSectionTitle(context, t.pages.settings.general.sectionMisc),
                const EnableAnalyticsPrefTile(),
                TechUi.formSwitchRow(
                  context,
                  title: t.pages.settings.general.autoIpCheck,
                  value: ref.watch(Preferences.autoCheckIp),
                  onChanged: ref.read(Preferences.autoCheckIp.notifier).update,
                ),
                TechUi.formSwitchRow(
                  context,
                  title: t.pages.settings.general.memoryLimit,
                  subtitle: t.pages.settings.general.memoryLimitMsg,
                  value: !ref.watch(Preferences.disableMemoryLimit),
                  onChanged: (value) async => await ref.read(Preferences.disableMemoryLimit.notifier).update(!value),
                ),
                TechUi.formSwitchRow(
                  context,
                  title: t.pages.settings.general.debugMode,
                  value: ref.watch(debugModeNotifierProvider),
                  onChanged: (value) async {
                    if (value) {
                      await ref
                          .read(dialogNotifierProvider.notifier)
                          .showOk(t.pages.settings.general.debugMode, t.pages.settings.general.debugModeMsg);
                    }
                    await ref.read(debugModeNotifierProvider.notifier).update(value);
                  },
                ),
                ChoicePreferenceWidget(
                  selected: ref.watch(ConfigOptions.logLevel),
                  preferences: ref.watch(ConfigOptions.logLevel.notifier),
                  choices: LogLevel.choices,
                  title: t.pages.settings.general.logLevel,
                  presentChoice: (value) => value.name.toUpperCase(),
                ),
                ValuePreferenceWidget(
                  value: ref.watch(ConfigOptions.connectionTestUrl),
                  preferences: ref.watch(ConfigOptions.connectionTestUrl.notifier),
                  title: t.pages.settings.general.connectionTestUrl,
                ),
                PreferenceRow(
                  title: t.pages.settings.general.urlTestInterval,
                  valueText: ref.watch(ConfigOptions.urlTestInterval).toApproximateTime(isRelativeToNow: false),
                  onTap: () async => await ref
                      .read(dialogNotifierProvider.notifier)
                      .showSettingSlider(
                        title: t.pages.settings.general.urlTestInterval,
                        initialValue: ref.watch(ConfigOptions.urlTestInterval).inMinutes.coerceIn(0, 60).toDouble(),
                        onReset: ref.read(ConfigOptions.urlTestInterval.notifier).reset,
                        min: 1,
                        max: 60,
                        divisions: 60,
                        labelGen: (value) =>
                            Duration(minutes: value.toInt()).toApproximateTime(isRelativeToNow: false),
                      )
                      .then((value) async {
                        if (value == null) return;
                        await ref
                            .read(ConfigOptions.urlTestInterval.notifier)
                            .update(Duration(minutes: value.toInt()));
                      }),
                ),
                ValuePreferenceWidget(
                  value: ref.watch(ConfigOptions.clashApiPort),
                  preferences: ref.watch(ConfigOptions.clashApiPort.notifier),
                  title: t.pages.settings.general.clashApiPort,
                  validateInput: isPort,
                  digitsOnly: true,
                  inputToValue: int.tryParse,
                ),
                TechUi.formSwitchRow(
                  context,
                  title: t.pages.settings.general.useXrayCoreWhenPossible,
                  subtitle: t.pages.settings.general.useXrayCoreWhenPossibleMsg,
                  value: ref.watch(ConfigOptions.useXrayCoreWhenPossible),
                  onChanged: ref.read(ConfigOptions.useXrayCoreWhenPossible.notifier).update,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype `.appearance-block`: theme-mode seg + "currently active" hint.
class _AppearanceBlock extends ConsumerWidget {
  const _AppearanceBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final themeMode = ref.watch(themePreferencesProvider);
    final displayed = themeMode == AppThemeMode.black ? AppThemeMode.dark : themeMode;
    final effective = theme.brightness == Brightness.dark
        ? t.pages.settings.general.themeModes.dark
        : t.pages.settings.general.themeModes.light;
    final accent = ConnectionButtonTheme.accentOf(context);

    return Container(
      decoration: TechUi.formRowDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.pages.settings.general.themeMode,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TechUi.seg<AppThemeMode>(
            context,
            options: const [AppThemeMode.light, AppThemeMode.dark, AppThemeMode.system],
            selected: displayed,
            label: (mode) => mode.present(t),
            onChanged: (mode) async => await ref.read(themePreferencesProvider.notifier).changeThemeMode(mode),
            height: 40,
            fontSize: 13,
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: '${t.pages.settings.general.appearanceActive}：',
              children: [
                TextSpan(
                  text: effective,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
