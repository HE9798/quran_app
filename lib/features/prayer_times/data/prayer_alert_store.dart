import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_models.dart';

/// Which prayers have their reminder switched on. Saved on the phone.
class PrayerAlertStore extends ChangeNotifier {
  PrayerAlertStore._();
  static final instance = PrayerAlertStore._();

  static const _key = 'prayer_alerts_v1';

  /// Same as the design: everything on except sunrise.
  Set<Prayer> _enabled = {
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  };

  Set<Prayer> get enabled => Set.unmodifiable(_enabled);
  bool isOn(Prayer prayer) => _enabled.contains(prayer);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_key);
      if (saved != null) {
        _enabled = {
          for (final p in Prayer.values)
            if (saved.contains(p.name)) p,
        };
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> set(Prayer prayer, bool on) async {
    if (on) {
      _enabled.add(prayer);
    } else {
      _enabled.remove(prayer);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, [for (final p in _enabled) p.name]);
    } catch (_) {}
  }
}
