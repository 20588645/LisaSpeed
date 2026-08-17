import Cocoa
import FlutterMacOS
import Network
import window_manager
import LaunchAtLogin
import UserNotifications

class MainFlutterWindow: NSWindow {
  private let lifecycleStreamHandler = LifecycleStreamHandler()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)


 // Add FlutterMethodChannel platform code
    FlutterMethodChannel(
      name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        result(LaunchAtLogin.isEnabled)
      case "launchAtStartupSetEnabled":
        if let arguments = call.arguments as? [String: Any] {
          LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Native OS notifications (Notification Center) so the connection watchdog
    // and quota alerts reach the user even when the window is hidden.
    FlutterMethodChannel(
      name: "com.lisaspeed/notify", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "show", let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      let content = UNMutableNotificationContent()
      content.title = args["title"] as? String ?? ""
      content.body = args["body"] as? String ?? ""
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: UUID().uuidString, content: content, trigger: nil
      )
      UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
      result(nil)
    }

    // Proper foreground activation for the menu-bar → window flow. Becoming a
    // regular app *before* activating is what lets the window form its own
    // Stage Manager group instead of overlapping another app's set.
    FlutterMethodChannel(
      name: "com.lisaspeed/window", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { [weak self] (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "activate" else {
        result(FlutterMethodNotImplemented)
        return
      }
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      self?.makeKeyAndOrderFront(nil)
      result(nil)
    }

    // Finder-quality .app icons for the dedicated-line picker and cards.
    FlutterMethodChannel(
      name: "com.lisaspeed/apps", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
      MacAppIcons.handle(call, result: result)
    }

    // Sleep/wake + network path changes so Dart can revive a stale tunnel.
    FlutterEventChannel(
      name: "com.lisaspeed/lifecycle",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setStreamHandler(lifecycleStreamHandler)
    //
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // window manager hidden at launch
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}

/// Renders `NSWorkspace` app icons to PNG. Flutter cannot decode `.icns`.
/// Runs on the platform thread (main) because AppKit drawing is not thread-safe.
private enum MacAppIcons {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "icon":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(nil)
        return
      }
      let size = args["size"] as? Int ?? 128
      let data = png(forAppAt: path, pixelSize: size)
      result(data.map { FlutterStandardTypedData(bytes: $0) })
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func png(forAppAt path: String, pixelSize: Int) -> Data? {
    guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
    let pixels = max(16, min(pixelSize, 256))
    let size = CGFloat(pixels)
    let icon = NSWorkspace.shared.icon(forFile: path)
    icon.size = NSSize(width: size, height: size)
    guard let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: pixels,
      pixelsHigh: pixels,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    icon.draw(
      in: NSRect(origin: .zero, size: NSSize(width: size, height: size)),
      from: .zero,
      operation: .sourceOver,
      fraction: 1.0,
      respectFlipped: false,
      hints: [.interpolation: NSImageInterpolation.high]
    )
    return rep.representation(using: .png, properties: [:])
  }
}

/// Emits `wake` after system sleep and `network` when the path returns after a drop
/// (hotspot / Wi-Fi switch). Dart reconnects the tunnel if the user had it on.
private final class LifecycleStreamHandler: NSObject, FlutterStreamHandler {
  private var events: FlutterEventSink?
  private var monitor: NWPathMonitor?
  private var lastSatisfied: Bool?
  private var wakeObserver: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.events = events
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.events?(["type": "wake"])
    }

    let monitor = NWPathMonitor()
    self.monitor = monitor
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      let satisfied = path.status == .satisfied
      if self.lastSatisfied == false && satisfied {
        self.events?(["type": "network"])
      }
      self.lastSatisfied = satisfied
    }
    monitor.start(queue: .main)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let wakeObserver {
      NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
    }
    wakeObserver = nil
    monitor?.cancel()
    monitor = nil
    events = nil
    lastSatisfied = nil
    return nil
  }
}

