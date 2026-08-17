import 'package:flutter/material.dart';
import 'package:hiddify/core/analytics/analytics_controller.dart';
import 'package:hiddify/core/localization/locale_extensions.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/theme/theme_preferences.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LocalePrefTile extends ConsumerWidget {
  const LocalePrefTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final locale = ref.watch(localePreferencesProvider);
    return PreferenceRow(
      title: t.pages.settings.general.locale,
      valueText: locale.localeName,
      onTap: () async {
        final selectedLocale = await ref
            .read(dialogNotifierProvider.notifier)
            .showSettingPicker<AppLocale>(
              title: t.pages.settings.general.locale,
              selected: locale,
              onReset: () => ref.read(localePreferencesProvider.notifier).changeLocale(AppLocale.en),
              options: AppLocale.values,
              getTitle: (e) => e.localeName,
            );
        if (selectedLocale != null) {
          await ref.read(localePreferencesProvider.notifier).changeLocale(selectedLocale);
        }
      },
    );
  }
}

class EnableAnalyticsPrefTile extends ConsumerWidget {
  const EnableAnalyticsPrefTile({super.key, this.onChanged});

  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final enabled = ref.watch(analyticsControllerProvider).requireValue;

    return TechUi.formSwitchRow(
      context,
      title: t.pages.settings.general.enableAnalytics,
      subtitle: t.pages.settings.general.enableAnalyticsMsg,
      value: enabled,
      onChanged: (value) async {
        if (onChanged != null) {
          return onChanged!(value);
        }
        if (enabled) {
          await ref.read(analyticsControllerProvider.notifier).disableAnalytics();
        } else {
          await ref.read(analyticsControllerProvider.notifier).enableAnalytics();
        }
      },
    );
  }
}

class ThemeModePrefTile extends ConsumerWidget {
  const ThemeModePrefTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final themeMode = ref.watch(themePreferencesProvider);

    return ListTile(
      title: Text(t.pages.settings.general.themeMode),
      subtitle: Text(themeMode.present(t)),
      leading: Icon(switch (ref.watch(themePreferencesProvider)) {
        AppThemeMode.system => Icons.auto_awesome_rounded,
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.dark => Icons.dark_mode_rounded,
        AppThemeMode.black => Icons.contrast_rounded,
      }),
      onTap: () async {
        final selectedThemeMode = await ref
            .read(dialogNotifierProvider.notifier)
            .showSettingPicker<AppThemeMode>(
              title: t.pages.settings.general.themeMode,
              selected: themeMode,
              onReset: () => ref.read(themePreferencesProvider.notifier).changeThemeMode(AppThemeMode.system),
              options: AppThemeMode.values,
              getTitle: (e) => e.present(t),
            );
        if (selectedThemeMode != null) {
          await ref.read(themePreferencesProvider.notifier).changeThemeMode(selectedThemeMode);
        }
      },
    );
  }
}

class ClosingPrefTile extends ConsumerWidget {
  const ClosingPrefTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final action = ref.watch(Preferences.actionAtClose);

    return PreferenceRow(
      title: t.pages.settings.general.actionAtClosing,
      valueText: action.present(t),
      onTap: () async {
        final selectedAction = await ref.read(dialogNotifierProvider.notifier).showActionAtClosing(selected: action);
        if (selectedAction != null) {
          await ref.read(Preferences.actionAtClose.notifier).update(selectedAction);
        }
      },
    );
  }
}

/// Prototype `.appearance-block`: theme-mode seg + "currently active" hint.
class AppearancePrefBlock extends ConsumerWidget {
  const AppearancePrefBlock({super.key});

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
