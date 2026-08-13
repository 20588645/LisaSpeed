import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
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
      // Prototype `.appearance-block`: 16px radius like the panels.
      decoration: TechUi.formRowDecoration(context).copyWith(
        borderRadius: BorderRadius.circular(16),
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
