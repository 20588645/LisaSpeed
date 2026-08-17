import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/per_app_proxy/overview/per_app_proxy_notifier.dart';
import 'package:hiddify/features/route_rules/notifier/rules_notifier.dart';
import 'package:hiddify/features/route_rules/widget/quick_site_rule_dialog.dart';
import 'package:hiddify/features/route_rules/widget/rule_tile.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RoutingOptionsPage extends HookConsumerWidget {
  const RoutingOptionsPage({super.key, required this.routeRule});

  // Import route rule from deep link
  final String? routeRule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final perAppProxy = ref.watch(Preferences.perAppProxyMode).enabled;
    final rules = ref.watch(rulesNotifierProvider);

    final menuItems = <PopupMenuEntry>[
      PopupMenuItem(
        onTap: ref.read(rulesNotifierProvider.notifier).importRulesFromClipboard,
        child: Text(t.pages.settings.routing.routeRule.options.import.clipboard),
      ),
      PopupMenuItem(
        onTap: ref.read(rulesNotifierProvider.notifier).importRulesFromJsonFile,
        child: Text(t.pages.settings.routing.routeRule.options.import.file),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        onTap: () async => await ref.read(rulesNotifierProvider.notifier).exportJsonToClipboard(),
        child: Text(t.pages.settings.routing.routeRule.options.export.clipboard),
      ),
      PopupMenuItem(
        onTap: () async => await ref.read(rulesNotifierProvider.notifier).saveRulesAsJsonFile(),
        child: Text(t.pages.settings.routing.routeRule.options.export.file),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        onTap: ref.read(rulesNotifierProvider.notifier).resetRules,
        child: Text(t.pages.settings.routing.routeRule.options.reset),
      ),
    ];

    useMemoized(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (routeRule != null && context.mounted) {
          await ref.read(rulesNotifierProvider.notifier).importRulesFromDeepLink(routeRule!);
        }
      });
    });
    Widget? androidPerAppPanel;
    if (PlatformUtils.isAndroid) {
      androidPerAppPanel = Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        child: Container(
          decoration: TechUi.panelDecoration(context),
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TechUi.formSectionTitle(context, t.pages.settings.routing.generalOptions.perAppProxy.title, first: true),
              const Gap(10),
              PreferenceRow(
                title: t.pages.settings.routing.generalOptions.perAppProxy.title,
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: perAppProxy,
                    onChanged: (value) async {
                      final newMode = perAppProxy ? PerAppProxyMode.off : PerAppProxyMode.exclude;
                      await ref.read(Preferences.perAppProxyMode.notifier).update(newMode);
                      if (!perAppProxy && context.mounted) context.goNamed('perAppProxy');
                    },
                  ),
                ),
                onTap: () async {
                  if (!perAppProxy) {
                    await ref.read(Preferences.perAppProxyMode.notifier).update(PerAppProxyMode.exclude);
                  }
                  if (context.mounted) context.goNamed('perAppProxy');
                },
              ),
            ],
          ),
        ),
      );
    }

    final rulesHeader = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            t.pages.settings.routing.ruleList.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(10),
          Expanded(
            child: Text(
              t.pages.settings.routing.ruleListHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: TechUi.subPageHeader(
              context,
              title: t.pages.settings.routing.title,
              subtitle: t.pages.settings.routing.desc,
              onBack: () => context.pop(),
              actions: [
                MenuAnchor(
                  menuChildren: [
                    for (final item in (rules.isEmpty ? menuItems.getRange(0, 2).toList() : menuItems))
                      if (item is PopupMenuItem)
                        MenuItemButton(
                          onPressed: item.onTap,
                          child: item.child ?? const SizedBox(),
                        ),
                  ],
                  builder: (context, controller, child) => TechUi.iconButton(
                    context,
                    icon: Icons.more_horiz_rounded,
                    onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                  ),
                ),
                TechUi.ghostButton(
                  context,
                  label: t.pages.settings.routing.predefinedRules.title,
                  onPressed: ref.read(bottomSheetsNotifierProvider.notifier).showPredefinedRules,
                ),
                TechUi.ghostButton(
                  context,
                  label: t.pages.settings.routing.routeRule.create,
                  onPressed: () => context.goNamed('rule', pathParameters: {'orderId': 'new'}),
                ),
                // Self-service entry: paste a site, pick 代理/直连/拦截, done.
                TechUi.primaryButton(
                  context,
                  label: t.pages.settings.routing.quickRule.title,
                  onPressed: () async => await QuickSiteRuleDialog.show(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: rules.isNotEmpty
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    buildDefaultDragHandles: false,
                    onReorder: ref.read(rulesNotifierProvider.notifier).reorder,
                    header: rulesHeader,
                    footer: androidPerAppPanel,
                    itemBuilder: (context, index) =>
                        RuleTile(key: Key('$index'), index: index, rule: rules[index]),
                    itemCount: rules.length,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    children: [
                      rulesHeader,
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: TechUi.panelDecoration(context),
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            t.pages.settings.routing.routeRule.empty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      if (androidPerAppPanel != null) androidPerAppPanel,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Region / balancer / IPv6 knobs — used by Advanced, not the everyday routing page.
List<Widget> routingEngineOptionRows(BuildContext context, WidgetRef ref, Translations t) {
  return [
    ChoicePreferenceWidget(
      selected: ref.watch(ConfigOptions.region),
      preferences: ref.watch(ConfigOptions.region.notifier),
      choices: Region.values,
      title: t.pages.settings.routing.generalOptions.region,
      showFlag: true,
      presentChoice: (value) => value.present(t),
      onChanged: (val) async {
        await ref.read(ConfigOptions.directDnsAddress.notifier).reset();
        final autoRegion = ref.read(Preferences.autoAppsSelectionRegion);
        final mode = ref.read(Preferences.perAppProxyMode).toAppProxy();
        if (autoRegion != val &&
            autoRegion != null &&
            val != Region.other &&
            mode != null &&
            PlatformUtils.isAndroid) {
          await ref
              .read(dialogNotifierProvider.notifier)
              .showOk(
                t.pages.settings.routing.generalOptions.perAppProxy.autoSelection.dialog.title,
                t.pages.settings.routing.generalOptions.perAppProxy.autoSelection.dialog.msg(
                  region: val.name,
                ),
              );
          await ref.read(PerAppProxyProvider(mode).notifier).clearAutoSelected();
        }
      },
    ),
    ChoicePreferenceWidget(
      title: t.pages.settings.routing.generalOptions.balancerStrategy.title,
      selected: ref.watch(ConfigOptions.balancerStrategy),
      preferences: ref.watch(ConfigOptions.balancerStrategy.notifier),
      choices: BalancerStrategy.values,
      presentChoice: (value) => value.present(t),
    ),
    TechUi.formSwitchRow(
      context,
      title: t.pages.settings.routing.generalOptions.resolveDestination,
      value: ref.watch(ConfigOptions.resolveDestination),
      onChanged: ref.read(ConfigOptions.resolveDestination.notifier).update,
    ),
    ChoicePreferenceWidget(
      selected: ref.watch(ConfigOptions.ipv6Mode),
      preferences: ref.watch(ConfigOptions.ipv6Mode.notifier),
      choices: IPv6Mode.values,
      title: t.pages.settings.routing.generalOptions.ipv6Route,
      presentChoice: (value) => value.present(t),
    ),
  ];
}
