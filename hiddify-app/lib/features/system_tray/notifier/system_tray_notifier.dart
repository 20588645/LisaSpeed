import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/locale_preferences.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/line_health/notifier/line_health_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/overview/proxy_display.dart';
import 'package:hiddify/features/proxy/overview/tray_proxy_menu.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/window/notifier/window_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

part 'system_tray_notifier.g.dart';

@Riverpod(keepAlive: true)
class SystemTrayNotifier extends _$SystemTrayNotifier with TrayListener, AppLogger {
  bool listenerAdded = false;
  @override
  Future<void> build() async {
    assert(PlatformUtils.isDesktop);
    if (!listenerAdded) {
      trayManager.addListener(this);
      listenerAdded = true;
    }
    await _initializeTray();
  }

  Future<void> _initializeTray() async {
    final activeProxy = await ref
        .watch(activeProxyNotifierProvider.future)
        .catchError((e) {
          loggy.warning("error getting active proxy", e);
          return OutboundInfo(urlTestDelay: 0);
        });
    final urlTestDelay = activeProxy.urlTestDelay;
    final connection = await ref
        .watch(connectionNotifierProvider.future)
        .catchError((e) {
          loggy.warning("error getting connection status", e);
          return const ConnectionStatus.disconnected();
        })
        .then((connection) => _modifyConnectionStatus(connection, urlTestDelay));
    final serviceMode = ref.watch(ConfigOptions.serviceMode);
    final t = await ref.watch(translationsProvider.future);
    final locale = ref.watch(localePreferencesProvider);
    final chinese = locale == AppLocale.zhCn || locale == AppLocale.zhTw;
    final nodeTitle = proxyDisplayTitle(activeProxy, chinese: chinese, autoLabel: t.pages.proxies.autoSelect);
    final delayText = proxyDelayLabel(
      urlTestDelay,
      testing: t.pages.home.delayTesting,
      timeout: t.pages.proxies.delay.timeout,
    );
    final group = ref.watch(proxiesOverviewNotifierProvider).valueOrNull;

    await trayManager.setIcon(
      _trayIconPath(connection),
      isTemplate: PlatformUtils.isMacOS,
      // Icon sits right of the speed readout so it stays put while the
      // numbers tick; text-left keeps the readout anchored beside it.
      iconPosition: PlatformUtils.isMacOS ? TrayIconPosition.right : TrayIconPosition.left,
    );
    if (!PlatformUtils.isLinux) {
      await trayManager.setToolTip(_trayTooltip(connection, nodeTitle, delayText, t));
    }
    await trayManager.setContextMenu(_trayMenu(connection, serviceMode, t, group, chinese));
  }

  Menu _trayMenu(
    ConnectionStatus connection,
    ServiceMode serviceMode,
    Translations t,
    OutboundGroup? group,
    bool chinese,
  ) {
    final nodes = group == null
        ? const <TrayProxyItem>[]
        : buildTrayProxyItems(
            group: group,
            chinese: chinese,
            autoLabel: t.pages.proxies.autoSelect,
          );
    return Menu(
      items: [
        MenuItem(key: 'dashboard', label: t.common.dashboard),
        MenuItem.separator(),
        MenuItem(
          key: 'connection',
          label: switch (connection) {
            Disconnected() => t.connection.connect,
            Connecting() => t.connection.connecting,
            Connected() => t.connection.disconnect,
            Disconnecting() => t.connection.disconnecting,
          },
          disabled: connection.isSwitching,
        ),
        MenuItem.submenu(
          label: t.pages.proxies.traySwitch,
          submenu: Menu(
            items: nodes.isEmpty
                ? [MenuItem(key: 'nodesHint', label: t.pages.proxies.trayNeedConnect, disabled: true)]
                : [
                    for (final node in nodes)
                      MenuItem.checkbox(
                        checked: node.selected,
                        key: node.menuKey,
                        label: node.label,
                        disabled: connection.isSwitching || connection is! Connected,
                      ),
                  ],
          ),
        ),
        MenuItem(key: 'lineHealth', label: t.pages.lineHealth.trayAction),
        MenuItem.submenu(
          label: t.pages.settings.inbound.serviceMode,
          icon: Assets.images.trayIconIco,
          submenu: Menu(
            items: [
              ...ServiceMode.values.map(
                (e) => MenuItem.checkbox(checked: e == serviceMode, key: e.name, label: e.present(t)),
              ),
            ],
          ),
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: t.common.quit),
      ],
    );
  }

  String _trayIconPath(ConnectionStatus status) {
    final isDarkMode = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    const images = Assets.images;
    final isWindows = PlatformUtils.isWindows;
    switch (status) {
      case Connected():
        return isWindows ? images.trayIconConnectedIco : images.trayIconConnectedPng.path;
      case Connecting():
      case Disconnecting():
        return isWindows ? images.trayIconDisconnectedIco : images.trayIconDisconnectedPng.path;
      case Disconnected():
        return isWindows
            ? isDarkMode
                  ? images.trayIconIco
                  : images.trayIconDarkIco
            : isDarkMode
            ? images.trayIconDarkPng.path
            : images.trayIconPng.path;
    }
  }

  String _trayTooltip(ConnectionStatus connection, String nodeTitle, String delayText, Translations t) {
    final r = "${Constants.appName} - ${connection.present(t)}";
    if (connection is Connected) {
      if (Platform.isMacOS) {
        final ms = int.tryParse(delayText.split(' ').first);
        windowManager.setBadgeLabel(ms != null ? '${ms}ms' : '');
      }
      return nodeTitle.isEmpty ? '$r · $delayText' : '$r · $nodeTitle · $delayText';
    } else {
      if (Platform.isMacOS) windowManager.setBadgeLabel("");
      return r;
    }
  }

  ConnectionStatus _modifyConnectionStatus(ConnectionStatus connection, int urlTestDelay) {
    return connection;
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    // if (menuItem.key == 'dashboard') {
    //   await ref.read(windowNotifierProvider.notifier).open();
    // }
    final key = menuItem.key;
    if (key == null || key == 'nodesHint') return;
    if (key == 'dashboard') {
      await ref.read(windowNotifierProvider.notifier).show();
    } else if (key == 'connection') {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    } else if (key == 'quit') {
      await ref.read(windowNotifierProvider.notifier).exit();
    } else if (key == 'lineHealth') {
      await ref.read(lineHealthProvider.notifier).run();
    } else if (TrayProxyItem.parseKey(key) case final parsed?) {
      try {
        await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(parsed.$1, parsed.$2);
      } catch (e) {
        loggy.warning("tray switch node failed", e);
      }
    } else {
      ServiceMode? newMode;
      for (final mode in ServiceMode.values) {
        if (mode.name == key) {
          newMode = mode;
          break;
        }
      }
      if (newMode == null) return;
      loggy.debug("switching service mode: [$newMode]");
      await ref.read(ConfigOptions.serviceMode.notifier).update(newMode);
    }
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    // if (Platform.isMacOS) {
    //   await trayManager.popUpContextMenu();
    // } else {
    //   await ref.read(windowNotifierProvider.notifier).hideOrShow();
    // }
    await ref.read(windowNotifierProvider.notifier).showOrHide();
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }
}

// @Riverpod(keepAlive: true)
// class SystemTrayNotifier extends _$SystemTrayNotifier with AppLogger {
//   @override
//   Future<void> build() async {
//     if (!PlatformUtils.isDesktop) return;

//     final activeProxy = await ref.watch(activeProxyNotifierProvider.future);
//     final delay = activeProxy.urlTestDelay;
//     final newConnectionStatus = delay > 0 && delay < 65000;
//     ConnectionStatus connection;
//     try {
//       connection = await ref.watch(connectionNotifierProvider.future);
//     } catch (e) {
//       loggy.warning("error getting connection status", e);
//       connection = const ConnectionStatus.disconnected();
//     }

//     final t = await ref.watch(translationsProvider.future);

//     var tooltip = Constants.appName;
//     final serviceMode = ref.watch(ConfigOptions.serviceMode);
//     if (connection is Disconnected) {
//       setIcon(connection);
//     } else if (newConnectionStatus) {
//       setIcon(const Connected());
//       tooltip = "$tooltip - ${connection.present(t)}";
//       if (newConnectionStatus) {
//         tooltip = "$tooltip : ${delay}ms";
//       } else {
//         tooltip = "$tooltip : -";
//       }
//       // else if (delay>1000)
//       //   SystemTrayNotifier.setIcon(timeout ? Disconnecting() : Connecting());
//     } else {
//       setIcon(const Disconnecting());
//       tooltip = "$tooltip - ${connection.present(t)}";
//     }
//     if (Platform.isMacOS) {
//       windowManager.setBadgeLabel("${delay}ms");
//     }
//     if (!Platform.isLinux) await trayManager.setToolTip(tooltip);

//     // final destinations = <(String label, String location)>[
//     //   (t.home.pageTitle, const HomeRoute().location),
//     //   (t.proxies.pageTitle, const ProfilesOverviewRoute().location),
//     //   (t.logs.title, const LogsOverviewRoute().location),
//     //   // (t.settings.pageTitle, const SettingsRoute().location),
//     //   (t.about.pageTitle, const AboutRoute().location),
//     // ];

//     // loggy.debug('updating system tray');

//     final menu = Menu(
//       items: [
//         MenuItem(
//           label: t.tray.dashboard,
//           onClick: (_) async {
//             await ref.read(windowNotifierProvider.notifier).open();
//           },
//         ),
//         MenuItem.separator(),
//         MenuItem.checkbox(
//           label: switch (connection) {
//             Disconnected() => t.tray.status.connect,
//             Connecting() => t.tray.status.connecting,
//             Connected() => t.tray.status.disconnect,
//             Disconnecting() => t.tray.status.disconnecting,
//           },
//           // checked: connection.isConnected,
//           checked: false,
//           disabled: connection.isSwitching,
//           onClick: (_) async {
//            await ref.read(connectionNotifierProvider.notifier).toggleConnection();
//          },
//        ),
//         MenuItem.separator(),
//         MenuItem(
//           label: t.config.serviceMode,
//           icon: Assets.images.trayIconIco,
//           disabled: true,
//         ),

//         ...ServiceMode.values.map(
//           (e) => MenuItem.checkbox(
//             checked: e == serviceMode,
//             key: e.name,
//             label: e.present(t),
//             onClick: (menuItem) async {
//               final newMode = ServiceMode.values.byName(menuItem.key!);
//               loggy.debug("switching service mode: [$newMode]");
//               await ref.read(ConfigOptions.serviceMode.notifier).update(newMode);
//             },
//           ),
//         ),

//         // MenuItem.submenu(
//         //   label: t.tray.open,
//         //   submenu: Menu(
//         //     items: [
//         //       ...destinations.map(
//         //         (e) => MenuItem(
//         //           label: e.$1,
//         //           onClick: (_) async {
//         //             await ref.read(windowNotifierProvider.notifier).open();
//         //             ref.read(routerProvider).go(e.$2);
//         //           },
//         //         ),
//         //       ),
//         //     ],
//         //   ),
//         // ),
//         MenuItem.separator(),
//         MenuItem(
//           label: t.tray.quit,
//           onClick: (_) async {
//             return ref.read(windowNotifierProvider.notifier).quit();
//           },
//         ),
//       ],
//     );

//     await trayManager.setContextMenu(menu);
//   }

//   static void setIcon(ConnectionStatus status) {
//     if (!PlatformUtils.isDesktop) return;
//     trayManager
//         .setIcon(
//           _trayIconPath(status),
//           isTemplate: Platform.isMacOS,
//         )
//         .asStream();
//   }

//   static String _trayIconPath(ConnectionStatus status) {
//     if (Platform.isWindows) {
//       final Brightness brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
//       final isDarkMode = brightness == Brightness.dark;
//       switch (status) {
//         case Connected():
//           return Assets.images.trayIconConnectedIco;
//         case Connecting():
//           return Assets.images.trayIconDisconnectedIco;
//         case Disconnecting():
//           return Assets.images.trayIconDisconnectedIco;
//         case Disconnected():
//           if (isDarkMode) {
//             return Assets.images.trayIconIco;
//           } else {
//             return Assets.images.trayIconDarkIco;
//           }
//       }
//     }
//     // const isDarkMode = false;
//     switch (status) {
//       case Connected():
//         return Assets.images.trayIconConnectedPng.path;
//       case Connecting():
//         return Assets.images.trayIconDisconnectedPng.path;
//       case Disconnecting():
//         return Assets.images.trayIconDisconnectedPng.path;
//       case Disconnected():
//         // if (isDarkMode) {
//         //   return Assets.images.trayIconDarkPng.path;
//         // } else {
//         //   return Assets.images.trayIconPng.path;
//         // }
//         return Assets.images.trayIconPng.path;
//     }
//     // return Assets.images.trayIconPng.path;
//   }
// }
