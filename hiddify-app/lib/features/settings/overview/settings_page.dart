import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final sections = <({String title, IconData icon, String location, Widget? subtitle})>[
      (
        title: t.pages.settings.general.title,
        icon: Icons.tune_rounded,
        location: context.namedLocation('general'),
        subtitle: null,
      ),
      (
        title: t.pages.settings.inbound.title,
        icon: Icons.lan_rounded,
        location: context.namedLocation('inboundOptions'),
        subtitle: null,
      ),
      (
        title: t.pages.settings.routing.title,
        icon: Icons.alt_route_rounded,
        location: context.namedLocation('routingOptions'),
        subtitle: null,
      ),
      (
        title: t.pages.settings.advanced.title,
        icon: Icons.construction_rounded,
        location: context.namedLocation('advancedOptions'),
        subtitle: Text(t.pages.settings.advanced.subtitle),
      ),
      (
        title: t.pages.logs.title,
        icon: Icons.terminal_rounded,
        location: context.namedLocation('logs'),
        subtitle: Text(t.pages.logs.subtitle),
      ),
      (
        title: t.pages.about.title,
        icon: Icons.info_outline_rounded,
        location: context.namedLocation('about'),
        subtitle: Text(t.pages.about.lead),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TechUi.pageIntro(
                      context,
                      eyebrow: 'Settings',
                      title: t.pages.settings.title,
                      subtitle: t.pages.settings.subtitle,
                    ),
                  ),
                  MenuAnchor(
                    menuChildren: <Widget>[
                      SubmenuButton(
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
                        child: Text(t.common.import),
                      ),
                      SubmenuButton(
                        menuChildren: <Widget>[
                          MenuItemButton(
                            onPressed: () async =>
                                await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                            child: Text(t.pages.settings.options.export.anonymousToClipboard),
                          ),
                          MenuItemButton(
                            onPressed: () async =>
                                await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                            child: Text(t.pages.settings.options.export.anonymousToFile),
                          ),
                          const PopupMenuDivider(),
                          MenuItemButton(
                            onPressed: () async => await ref
                                .read(configOptionNotifierProvider.notifier)
                                .exportJsonClipboard(excludePrivate: false),
                            child: Text(t.pages.settings.options.export.allToClipboard),
                          ),
                          MenuItemButton(
                            onPressed: () async => await ref
                                .read(configOptionNotifierProvider.notifier)
                                .exportJsonFile(excludePrivate: false),
                            child: Text(t.pages.settings.options.export.allToFile),
                          ),
                        ],
                        child: Text(t.common.export),
                      ),
                      const PopupMenuDivider(),
                      MenuItemButton(
                        child: Text(t.pages.settings.options.reset),
                        onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
                      ),
                    ],
                    builder: (context, controller, child) => IconButton(
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              children: [
                for (var i = 0; i < sections.length; i++)
                  TechUi.hubCard(
                    context,
                    index: i + 1,
                    icon: sections[i].icon,
                    title: sections[i].title,
                    subtitle: sections[i].subtitle,
                    onTap: () => context.go(sections[i].location),
                  ),
                if (PlatformUtils.isIOS)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await ref.read(resetTunnelNotifierProvider.notifier).run();
                        },
                        child: Ink(
                          decoration: TechUi.panelDecoration(context),
                          child: ListTile(
                            title: Text(t.pages.settings.resetTunnel),
                            leading: Icon(Icons.autorenew_rounded, color: ConnectionButtonTheme.brandMint),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
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

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
    this.index = 1,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TechUi.hubCard(
      context,
      index: index,
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => context.go(namedLocation),
    );
  }
}
