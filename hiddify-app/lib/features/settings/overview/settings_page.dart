import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/auto_start/notifier/auto_start_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/dev_update/widget/local_update_dialog.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/features/settings/widget/restore_network_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsPage extends HookConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final autoStart = ref.watch(autoStartNotifierProvider);
    final hostEnabled = ref.watch(Preferences.hostPanelEnabled);

    final everyday = <Widget>[
      TechUi.formSectionTitle(context, t.pages.settings.general.sectionAppearance, first: true),
      const LocalePrefTile(),
      const AppearancePrefBlock(),
      TechUi.formSectionTitle(context, t.pages.settings.inbound.sectionMode),
      ChoicePreferenceWidget(
        selected: ref.watch(ConfigOptions.serviceMode),
        preferences: ref.watch(ConfigOptions.serviceMode.notifier),
        choices: ServiceMode.choices,
        title: t.pages.settings.inbound.serviceMode,
        presentChoice: (value) => value.present(t),
      ),
      TechUi.formSwitchRow(
        context,
        title: t.connection.watchdog.autoReconnect,
        subtitle: t.connection.watchdog.autoReconnectMsg,
        value: ref.watch(Preferences.autoReconnectOnStall),
        onChanged: ref.read(Preferences.autoReconnectOnStall.notifier).update,
      ),
      if (PlatformUtils.isMacOS) ...[
        TechUi.formSectionTitle(context, t.pages.settings.general.sectionNetwork),
        const RestoreNetworkTile(),
      ],
      if (PlatformUtils.isDesktop) ...[
        TechUi.formSectionTitle(context, t.pages.settings.general.sectionStartup),
        const ClosingPrefTile(),
        TechUi.formSwitchRow(
          context,
          title: t.pages.settings.general.autoStart,
          value: autoStart.value ?? false,
          onChanged: autoStart.isLoading
              ? null
              : (value) async => value
                    ? await ref.read(autoStartNotifierProvider.notifier).enable()
                    : await ref.read(autoStartNotifierProvider.notifier).disable(),
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
      TechUi.formSectionTitle(context, t.pages.settings.general.sectionHostPanel),
      TechUi.formSwitchRow(
        context,
        title: t.pages.settings.general.hostPanelEnabled,
        subtitle: t.pages.settings.general.hostPanelEnabledMsg,
        value: hostEnabled,
        onChanged: ref.read(Preferences.hostPanelEnabled.notifier).update,
      ),
      if (hostEnabled) ...[
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
    ];

    final more = <({String title, String desc, String location})>[
      (
        title: t.pages.settings.routing.title,
        desc: t.pages.settings.routing.desc,
        location: context.namedLocation('routingOptions'),
      ),
      (
        title: t.pages.about.title,
        desc: t.pages.about.desc,
        location: context.namedLocation('about'),
      ),
      (
        title: t.pages.settings.advanced.title,
        desc: t.pages.settings.advanced.subtitle,
        location: context.namedLocation('advancedOptions'),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.pageIntro(
              context,
              title: t.pages.settings.title,
              subtitle: t.pages.settings.subtitle,
              action: PlatformUtils.isMacOS
                  ? TechUi.primaryButton(
                      context,
                      label: t.pages.about.localUpdate,
                      onPressed: () => LocalUpdateDialog.show(context),
                    )
                  : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: TechUi.pageBodyPadding,
              children: [
                Container(
                  decoration: TechUi.panelDecoration(context),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, child) in everyday.indexed) ...[
                        if (i > 0) const SizedBox(height: 10),
                        child,
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TechUi.formSectionTitle(context, t.pages.settings.sectionMore, first: true),
                const SizedBox(height: 8),
                for (final (i, item) in more.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _MoreEntry(
                    title: item.title,
                    desc: item.desc,
                    onTap: () => context.go(item.location),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreEntry extends StatelessWidget {
  const _MoreEntry({
    required this.title,
    required this.desc,
    required this.onTap,
  });

  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TechUi.listRow(
      context,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '›',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 20,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
