import 'package:flutter/services.dart';

/// Companion mode (Android): a little character floating over other apps.
class CompanionWidget {
  CompanionWidget._();

  static const _channel = MethodChannel('werd/companion');

  /// permission = "Display over other apps" allowed; enabled = companion mode
  /// is on; hidden = the character was put away on the X but its reminders
  /// were kept; type = "sheikh" or "sister"; bubbles = speech bubbles allowed.
  static Future<({bool permission, bool enabled, bool hidden, String type, bool bubbles})> state() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('state');
      return (
        permission: (m?['permission'] as bool?) ?? false,
        enabled: (m?['enabled'] as bool?) ?? false,
        hidden: (m?['hidden'] as bool?) ?? false,
        type: (m?['type'] as String?) ?? 'sheikh',
        bubbles: (m?['bubbles'] as bool?) ?? true,
      );
    } catch (_) {
      return (permission: false, enabled: false, hidden: false, type: 'sheikh', bubbles: true);
    }
  }

  /// The pictures live in assets/companion/ only. This copies them to the
  /// phone side, which draws the floating companion from them. It is done
  /// before the companion starts, so replacing a picture in the assets is all
  /// that is needed. (Later, the outfit the user chose will be sent here too.)
  /// Returns true when a picture on the phone side was changed.
  static Future<bool> syncImages() async {
    try {
      final images = <String, Uint8List>{};
      for (final name in const ['sheikh_body', 'sheikh_head', 'sister_body', 'sister_head']) {
        final data = await rootBundle.load('assets/companion/$name.png');
        images[name] = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      return await _channel.invokeMethod<bool>('syncImages', images) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the companion ("sheikh" or "sister"). False = permission missing.
  static Future<bool> start(String type) async {
    try {
      await syncImages();
      return await _channel.invokeMethod<bool>('start', type) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the character again after it was put away on the X.
  static Future<bool> show() async {
    try {
      await syncImages();
      return await _channel.invokeMethod<bool>('show') ?? false;
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
      final changed = await syncImages();
      await _channel.invokeMethod<void>('restore', changed);
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

  // ------------------------------------------------ on the lock screen

  /// enabled = the user wants the companion on the lock screen;
  /// allowed = Android lets the app show it full screen there (Android 14+
  /// asks the user; always true before that).
  static Future<({bool enabled, bool allowed})> lockState() async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('lockState');
      return (
        enabled: (m?['enabled'] as bool?) ?? true,
        allowed: (m?['allowed'] as bool?) ?? true,
      );
    } catch (_) {
      return (enabled: false, allowed: false);
    }
  }

  static Future<void> setLockScreen(bool on) async {
    try {
      await _channel.invokeMethod<void>('setLockScreen', on);
    } catch (_) {}
  }

  /// Opens the phone's page to allow full-screen notifications (Android 14+).
  static Future<void> openLockPermission() async {
    try {
      await _channel.invokeMethod<void>('lockPermission');
    } catch (_) {}
  }

}
