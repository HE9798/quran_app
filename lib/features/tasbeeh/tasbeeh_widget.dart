import 'package:flutter/services.dart';

/// The floating Tasbeeh button over other apps (Android only). It counts by
/// itself; the app only turns it on/off and can reset the count.
class TasbeehWidget {
  TasbeehWidget._();

  static const _channel = MethodChannel('werd/tasbeeh_widget');

  /// Sets the count and the combo back to zero.
  static Future<void> reset() async {
    try {
      await _channel.invokeMethod<void>('reset');
    } catch (_) {}
  }

  static Future<({int count, int combo})?> state() async {
    try {
      final m = await _channel.invokeMapMethod<String, int>('state');
      if (m == null) return null;
      return (count: m['count'] ?? 0, combo: m['combo'] ?? 0);
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------- floating button

  /// permission = "Display over other apps" allowed; enabled = button is on.
  static Future<({bool permission, bool enabled})> overlayState() async {
    try {
      final m = await _channel.invokeMapMethod<String, bool>('overlayState');
      return (permission: m?['permission'] ?? false, enabled: m?['enabled'] ?? false);
    } catch (_) {
      return (permission: false, enabled: false);
    }
  }

  /// Opens the phone's "Display over other apps" page for this app.
  static Future<void> openOverlayPermission() async {
    try {
      await _channel.invokeMethod<void>('overlayPermission');
    } catch (_) {}
  }

  /// Shows the floating button. False when the permission is missing.
  static Future<bool> startOverlay() async {
    try {
      return await _channel.invokeMethod<bool>('overlayStart') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stopOverlay() async {
    try {
      await _channel.invokeMethod<void>('overlayStop');
    } catch (_) {}
  }

  /// Call when the app starts: brings the button back if it was on.
  static Future<void> restoreOverlay() async {
    try {
      await _channel.invokeMethod<void>('overlayRestore');
    } catch (_) {}
  }
}
