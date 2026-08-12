import Cocoa
import FlutterMacOS

import UserNotifications
@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // https://github.com/leanflutter/window_manager/issues/214
    return false
  }

  // Cmd+Q and the app-menu Quit go through terminate: and bypass Flutter's
  // window-close cleanup (WindowNotifier.exit -> abortConnection). Without a
  // teardown here, quitting that way leaves the privileged root tunnel alive
  // with its TUN/routes and /etc/hosts overrides in place, which can break
  // connectivity (including domestic sites) until a manual network reset.
  //
  // `HiddifyCli tunnel exit` tells the root helper to close the TUN, restore
  // DNS/hosts and exit. It is a localhost gRPC client (no root needed to send)
  // and returns fast; when no tunnel is running it is a harmless no-op.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let binDir = Bundle.main.executableURL?.deletingLastPathComponent() else {
      return .terminateNow
    }
    let cli = binDir.appendingPathComponent("HiddifyCli")
    guard FileManager.default.fileExists(atPath: cli.path) else {
      return .terminateNow
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let proc = Process()
      proc.executableURL = cli
      proc.arguments = ["tunnel", "exit"]
      do {
        try proc.run()
      } catch {
        DispatchQueue.main.async { NSApp.reply(toApplicationShouldTerminate: true) }
        return
      }
      // Wait for teardown, but cap it so quitting never hangs on a stuck helper.
      let finished = DispatchSemaphore(value: 0)
      DispatchQueue.global().async {
        proc.waitUntilExit()
        finished.signal()
      }
      _ = finished.wait(timeout: .now() + 4.0)
      DispatchQueue.main.async { NSApp.reply(toApplicationShouldTerminate: true) }
    }
    return .terminateLater
  }
  
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  override func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    }


  // // window manager restore from dock: https://leanflutter.dev/blog/click-dock-icon-to-restore-after-closing-the-window
  // override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
  //     if !flag {
  //         for window in NSApp.windows {
  //             if !window.isVisible {
  //                 window.setIsVisible(true)
  //             }
  //             window.makeKeyAndOrderFront(self)
  //             NSApp.activate(ignoringOtherApps: true)
  //         }
  //     }
  //     return true
  // }
}
