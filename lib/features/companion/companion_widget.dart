import 'package:flutter/services.dart';

/// Companion mode (Android): a little character floating over other apps.
class CompanionWidget {
  CompanionWidget._();

  static const _channel = MethodChannel('werd/companion');

  /// permission = "Display over other apps" allowed; enabled = companion is on;
  /// type = "sheikh" or "sister".
  static Future<({bool permission, bool enabled, String type})> state() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('state');
      return (
        permission: (m?['permission'] as bool?) ?? false,
        enabled: (m?['enabled'] as bool?) ?? false,
        type: (m?['type'] as String?) ?? 'sheikh',
      );
    } catch (_) {
      return (permission: false, enabled: false, type: 'sheikh');
    }
  }

  /// Shows the companion ("sheikh" or "sister"). False = permission missing.
  static Future<bool> start(String type) async {
    try {
      return await _channel.invokeMethod<bool>('start', type) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }

  /// Call when the app starts: brings the companion back if it was on.
  static Future<void> restore() async {
    try {
      await _channel.invokeMethod<void>('restore');
    } catch (_) {}
  }
}
