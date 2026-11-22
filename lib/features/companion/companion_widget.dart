import 'package:flutter/services.dart';

/// Companion mode (Android): a little character floating over other apps.
class CompanionWidget {
  CompanionWidget._();

  static const _channel = MethodChannel('werd/companion');

  /// permission = "Display over other apps" allowed; enabled = companion is on;
  /// type = "sheikh" or "sister"; bubbles = speech bubbles allowed.
  static Future<({bool permission, bool enabled, String type, bool bubbles})> state() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('state');
      return (
        permission: (m?['permission'] as bool?) ?? false,
        enabled: (m?['enabled'] as bool?) ?? false,
        type: (m?['type'] as String?) ?? 'sheikh',
        bubbles: (m?['bubbles'] as bool?) ?? true,
      );
    } catch (_) {
      return (permission: false, enabled: false, type: 'sheikh', bubbles: true);
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

  /// A speech bubble above the companion, now.
  static Future<void> say(String text, {int ms = 5000}) async {
    try {
      await _channel.invokeMethod<void>('say', {'text': text, 'ms': ms});
    } catch (_) {}
  }

  /// Plans bubbles for later. Each event: id, at (ms since 1970), text.
  /// Replaces everything planned before. An empty list cancels all.
  static Future<void> scheduleBubbles(List<({int id, int at, String text})> events) async {
    try {
      await _channel.invokeMethod<void>('scheduleBubbles', [
        for (final e in events) {'id': e.id, 'at': e.at, 'text': e.text},
      ]);
    } catch (_) {}
  }

  /// Coins the floating Tasbeeh button earned while the app was closed.
  /// Returns them once, then they are zero again.
  static Future<int> claimTasbeehCoins() async {
    try {
      return await _channel.invokeMethod<int>('claimPending') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Phrases for the bubbles that the phone side makes by itself.
  static Future<void> setStrings(Map<String, String> strings) async {
    try {
      await _channel.invokeMethod<void>('setStrings', strings);
    } catch (_) {}
  }

  static Future<void> setBubbles(bool on) async {
    try {
      await _channel.invokeMethod<void>('setBubbles', on);
    } catch (_) {}
  }
}
