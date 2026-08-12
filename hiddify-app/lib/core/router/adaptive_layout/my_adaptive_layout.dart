import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/adaptive_layout/shell_route_action.dart';
import 'package:hiddify/core/router/adaptive_layout/tech_sidebar.dart';
import 'package:hiddify/core/router/go_router/routing_config_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/tech_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MyAdaptiveLayout extends HookConsumerWidget {
  const MyAdaptiveLayout({
    super.key,
    required this.navigationShell,
    required this.isMobileBreakpoint,
    required this.showProfilesAction,
  });
  final StatefulNavigationShell navigationShell;
  final bool isMobileBreakpoint;
  final bool showProfilesAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final primaryFocusHash = useState<int?>(null);
    final navScopeNode = useFocusScopeNode();
    useEffect(() {
      bool handler(KeyEvent event) {
        final arrows = isMobileBreakpoint ? KeyboardConst.verticalArrows : KeyboardConst.horizontalArrows;
        if (!arrows.contains(event.logicalKey)) return false;
        if (event is KeyDownEvent) {
          primaryFocusHash.value = FocusManager.instance.primaryFocus.hashCode;
        } else {
          if (primaryFocusHash.value == FocusManager.instance.primaryFocus.hashCode) {
            if (branchesScope.values.any((node) => node.hasFocus)) {
              navScopeNode.requestFocus();
            } else if (navScopeNode.hasFocus) {
              branchesScope[getNameOfBranch(isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex)]
                  ?.requestFocus();
            }
          }
        }
        return true;
      }

      HardwareKeyboard.instance.addHandler(handler);
      return () {
        HardwareKeyboard.instance.removeHandler(handler);
      };
    }, [isMobileBreakpoint, showProfilesAction, navigationShell.currentIndex]);

    final actions = _actions(t);
    final destinations = actions.map((e) => (icon: e.icon, label: e.title)).toList();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: isMobileBreakpoint
            ? TechUi.pageShell(context: context, child: navigationShell)
            : Row(
                children: [
                  FocusScope(
                    node: navScopeNode,
                    child: TechSidebar(
                      selectedIndex: navigationShell.currentIndex.clamp(0, 3),
                      onSelected: (index) => _onTap(context, index),
                      destinations: destinations,
                    ),
                  ),
                  Expanded(child: TechUi.pageShell(context: context, child: navigationShell)),
                ],
              ),
        bottomNavigationBar: isMobileBreakpoint
            ? FocusScope(
                node: navScopeNode,
                child: NavigationBar(
                  backgroundColor: ConnectionButtonTheme.panelOf(context),
                  indicatorColor: ConnectionButtonTheme.accentOf(context).withValues(alpha: 0.16),
                  selectedIndex: navigationShell.currentIndex.clamp(0, 3),
                  destinations: _navDests(actions),
                  onDestinationSelected: (index) => _onTap(context, index),
                ),
              )
            : null,
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  List<ShellRouteAction> _actions(Translations t) => [
    ShellRouteAction(Icons.home_rounded, t.pages.home.title),
    ShellRouteAction(Icons.hub_rounded, t.pages.proxies.title),
    ShellRouteAction(Icons.subscriptions_rounded, t.pages.profiles.title),
    ShellRouteAction(Icons.settings_rounded, t.pages.settings.title),
  ];

  List<NavigationDestination> _navDests(List<ShellRouteAction> actions) =>
      actions.map((e) => NavigationDestination(icon: Icon(e.icon), label: e.title)).toList();
}
