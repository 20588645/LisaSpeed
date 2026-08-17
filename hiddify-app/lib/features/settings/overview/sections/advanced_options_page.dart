import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/log/model/log_level.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/features/settings/overview/sections/chain_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/dns_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/routing_options_page.dart';
import 'package:hiddify/features/settings/overview/sections/tls_tricks_page.dart';
import 'package:hiddify/features/settings/widget/lan_sharing_tile.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:humanizer/humanizer.dart';

/// 高级 is the deep-options drawer: everything a typical day doesn't need —
/// core/network knobs, DNS, TLS tricks, the chain booster and the debug
/// toggles — lives here so the everyday pages stay short.
class AdvancedOptionsPage extends HookConsumerWidget {
  const AdvancedOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final hasProfile = ref.watch(hasAnyProfileProvider).value ?? false;

    final coreRows = <Widget>[
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
      ValuePreferenceWidget(
        value: ref.watch(ConfigOptions.mixedPort),
        preferences: ref.watch(ConfigOptions.mixedPort.notifier),
        title: t.pages.settings.inbound.mixedPort,
        inputToValue: int.tryParse,
        digitsOnly: true,
        validateInput: isPort,
        trailing: SwitchPreferenceWidget(preference: ConfigOptions.enableMixedPort),
      ),
      const LanSharingPreferenceWidget(),
      TechUi.formSwitchRow(
        context,
        title: t.pages.settings.general.autoIpCheck,
        value: ref.watch(Preferences.autoCheckIp),
        onChanged: ref.read(Preferences.autoCheckIp.notifier).update,
      ),
      TechUi.formSwitchRow(
        context,
        title: t.pages.settings.general.useXrayCoreWhenPossible,
        subtitle: t.pages.settings.general.useXrayCoreWhenPossibleMsg,
        value: ref.watch(ConfigOptions.useXrayCoreWhenPossible),
        onChanged: ref.read(ConfigOptions.useXrayCoreWhenPossible.notifier).update,
      ),
      TechUi.formSwitchRow(
        context,
        title: t.pages.settings.general.memoryLimit,
        subtitle: t.pages.settings.general.memoryLimitMsg,
        value: !ref.watch(Preferences.disableMemoryLimit),
        onChanged: (value) async => await ref.read(Preferences.disableMemoryLimit.notifier).update(!value),
      ),
    ];

    final debugRows = <Widget>[
      if (PlatformUtils.isDesktop)
        TechUi.formSwitchRow(
          context,
          title: t.pages.settings.general.silentStart,
          value: ref.watch(Preferences.silentStart),
          onChanged: ref.read(Preferences.silentStart.notifier).update,
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
              labelGen: (value) => Duration(minutes: value.toInt()).toApproximateTime(isRelativeToNow: false),
            )
            .then((value) async {
              if (value == null) return;
              await ref.read(ConfigOptions.urlTestInterval.notifier).update(Duration(minutes: value.toInt()));
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
      const EnableAnalyticsPrefTile(),
    ];

    final dnsRows = dnsOptionRows(context, ref, t);
    final tlsRows = tlsTrickRows(context, ref, t);
    final routingRows = routingEngineOptionRows(context, ref, t);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
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
                      TechUi.formSectionTitle(context, t.pages.settings.advanced.sectionCore, first: true),
                      for (final row in coreRows) ...[
                        const SizedBox(height: 10),
                        row,
                      ],
                      TechUi.formSectionTitle(context, t.pages.settings.advanced.sectionRouting),
                      for (final row in routingRows) ...[
                        const SizedBox(height: 10),
                        row,
                      ],
                      TechUi.formSectionTitle(context, t.pages.settings.dns.title),
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
                const SizedBox(height: 16),
                Container(
                  decoration: TechUi.panelDecoration(context),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TechUi.formSectionTitle(context, t.pages.settings.advanced.sectionDebug, first: true),
                      for (final row in debugRows) ...[
                        const SizedBox(height: 10),
                        row,
                      ],
                      const SizedBox(height: 12),
                      _ConfigBackupActions(),
                      if (PlatformUtils.isIOS) ...[
                        const SizedBox(height: 10),
                        PreferenceRow(
                          title: t.pages.settings.resetTunnel,
                          onTap: () async => await ref.read(resetTunnelNotifierProvider.notifier).run(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigBackupActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MenuAnchor(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () async => await ref
                  .read(dialogNotifierProvider.notifier)
                  .showConfirmation(
                    title: t.common.msg.import.confirm,
                    message: t.dialogs.confirmation.settings.import.msg,
                  )
                  .then((shouldImport) async {
                    if (shouldImport) {
                      await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                    }
                  }),
              child: Text(t.pages.settings.options.import.clipboard),
            ),
            MenuItemButton(
              onPressed: () async => await ref
                  .read(dialogNotifierProvider.notifier)
                  .showConfirmation(
                    title: t.common.msg.import.confirm,
                    message: t.dialogs.confirmation.settings.import.msg,
                  )
                  .then((shouldImport) async {
                    if (shouldImport) {
                      await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                    }
                  }),
              child: Text(t.pages.settings.options.import.file),
            ),
          ],
          builder: (context, controller, child) => TechUi.ghostButton(
            context,
            label: t.common.import,
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
        MenuAnchor(
          menuChildren: <Widget>[
            MenuItemButton(
              onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
              child: Text(t.pages.settings.options.export.anonymousToClipboard),
            ),
            MenuItemButton(
              onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
              child: Text(t.pages.settings.options.export.anonymousToFile),
            ),
            const PopupMenuDivider(),
            MenuItemButton(
              onPressed: () async =>
                  await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(excludePrivate: false),
              child: Text(t.pages.settings.options.export.allToClipboard),
            ),
            MenuItemButton(
              onPressed: () async =>
                  await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
              child: Text(t.pages.settings.options.export.allToFile),
            ),
          ],
          builder: (context, controller, child) => TechUi.ghostButton(
            context,
            label: t.common.export,
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          ),
        ),
        TechUi.ghostButton(
          context,
          label: t.pages.settings.options.reset,
          onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
        ),
      ],
    );
  }
}
