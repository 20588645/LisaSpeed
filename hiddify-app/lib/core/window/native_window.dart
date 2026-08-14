import 'package:flutter/services.dart';
import 'package:hiddify/utils/platform_utils.dart';

/// Brings the window forward as a proper foreground app. On macOS this switches
/// to a regular activation policy, activates the app (so the window forms its
/// own Stage Manager group instead of floating over another app's group) and
/// orders the window to the front. No-op where the native channel isn't wired.
class NativeWindow {
  NativeWindow._();

  static const _channel = MethodChannel('com.lisaspeed/window');

  static Future<void> activate() async {
    if (!PlatformUtils.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('activate');
    } catch (_) {
      // Older native build without the handler; window_manager's focus() still
      // ran, so this is only a best-effort enhancement.
    }
  }
}
