import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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

    final sections = <({String title, String desc, String location})>[
      (
        title: t.pages.settings.general.title,
        desc: t.pages.settings.general.desc,
        location: context.namedLocation('general'),
      ),
      (
        title: t.pages.settings.inbound.title,
        desc: t.pages.settings.inbound.desc,
        location: context.namedLocation('inboundOptions'),
      ),
      (
        title: t.pages.settings.routing.title,
        desc: t.pages.settings.routing.desc,
        location: context.namedLocation('routingOptions'),
      ),
      (
        title: t.pages.settings.advanced.title,
        desc: t.pages.settings.advanced.subtitle,
        location: context.namedLocation('advancedOptions'),
      ),
      (
        title: t.pages.logs.title,
        desc: t.pages.logs.desc,
        location: context.namedLocation('logs'),
      ),
      (
        title: t.pages.about.title,
        desc: t.pages.about.desc,
        location: context.namedLocation('about'),
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
                  const SizedBox(width: 8),
                  MenuAnchor(
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
                    builder: (context, controller, child) => TechUi.ghostButton(
                      context,
                      label: t.common.export,
                      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TechUi.ghostButton(
                    context,
                    label: t.pages.settings.options.reset,
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Prototype `.settings-grid`: two columns of numbered cards.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 560;
                    if (!twoColumns) {
                      return Column(
                        children: [
                          for (final (i, section) in sections.indexed) ...[
                            if (i > 0) const Gap(12),
                            TechUi.hubCard(
                              context,
                              index: i + 1,
                              title: section.title,
                              subtitle: Text(section.desc),
                              onTap: () => context.go(section.location),
                            ),
                          ],
                        ],
                      );
                    }
                    return Column(
                      children: [
                        for (var row = 0; row < sections.length; row += 2) ...[
                          if (row > 0) const Gap(12),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var col = 0; col < 2; col++) ...[
                                  if (col > 0) const Gap(12),
                                  Expanded(
                                    child: row + col < sections.length
                                        ? TechUi.hubCard(
                                            context,
                                            index: row + col + 1,
                                            title: sections[row + col].title,
                                            subtitle: Text(sections[row + col].desc),
                                            onTap: () => context.go(sections[row + col].location),
                                          )
                                        : const SizedBox(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                if (PlatformUtils.isIOS)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
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
                            leading: const Icon(Icons.autorenew_rounded, color: ConnectionButtonTheme.brandMint),
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
    this.subtitle,
    required this.namedLocation,
    this.index = 1,
  });

  final String title;
  final Widget? subtitle;
  final String namedLocation;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TechUi.hubCard(
      context,
      index: index,
      title: title,
      subtitle: subtitle,
      onTap: () => context.go(namedLocation),
    );
  }
}
