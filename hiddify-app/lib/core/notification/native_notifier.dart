import 'package:flutter/services.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// Posts a native OS notification (macOS Notification Center) so alerts stay
/// visible even when the window is hidden — LisaSpeed runs mostly from the
/// menu bar. A no-op where the native channel isn't wired (other platforms,
/// or a build that predates the Swift handler).
class NativeNotifier {
  NativeNotifier._();

  static const _channel = MethodChannel('com.lisaspeed/notify');

  static Future<void> show(String title, String body) async {
    if (!PlatformUtils.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('show', {'title': title, 'body': body});
    } catch (_) {
      // Channel unavailable (e.g. running an older native build); ignore so a
      // failed notification can never break the caller.
    }
  }
}
