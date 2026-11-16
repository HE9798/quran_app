import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All the user's settings in one place, saved on the phone.
/// Screens listen to this, so a change shows up immediately.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  static const _kFollow = 'set_follow_device_v1';
  static const _kDark = 'set_dark_v1';
  static const _kLang = 'set_lang_v1';
  static const _kFont = 'set_font_scale_v1';
  static const _kNotif = 'set_notifications_v1';
  static const _kVibrate = 'set_vibration_v1';
  static const _kMorning = 'set_azkar_morning_v1';
  static const _kEvening = 'set_azkar_evening_v1';
  static const _kAdhanSound = 'set_adhan_sound_v1';
  static const _kAdhanVoice = 'set_adhan_voice_v1';

  static const minFontScale = 0.85;
  static const maxFontScale = 1.4;

  SharedPreferences? _prefs;

  // ---- defaults
  bool followDevice = true; //  theme follows the phone by default
  bool darkMode = false; //     used only when followDevice is false
  String languageCode = 'en'; // 'en' or 'ar'
  double fontScale = 1.0;
  bool notifications = true; // master switch for every reminder
  bool vibration = true;
  bool azkarMorning = false;
  bool azkarEvening = false;
  bool adhanSound = true; //      false = prayer notifications are silent
  String adhanVoice = 'makkah'; // chosen adhan, independent of the Quran reciter

  ThemeMode get themeMode => followDevice
      ? ThemeMode.system
      : (darkMode ? ThemeMode.dark : ThemeMode.light);

  Locale get locale => Locale(languageCode);
  bool get isArabic => languageCode == 'ar';

  Future<void> load() async {
    try {
      final p = _prefs = await SharedPreferences.getInstance();
      followDevice = p.getBool(_kFollow) ?? followDevice;
      darkMode = p.getBool(_kDark) ?? darkMode;
      languageCode = p.getString(_kLang) ?? languageCode;
      fontScale = (p.getDouble(_kFont) ?? fontScale)
          .clamp(minFontScale, maxFontScale);
      notifications = p.getBool(_kNotif) ?? notifications;
      vibration = p.getBool(_kVibrate) ?? vibration;
      azkarMorning = p.getBool(_kMorning) ?? azkarMorning;
      azkarEvening = p.getBool(_kEvening) ?? azkarEvening;
      adhanSound = p.getBool(_kAdhanSound) ?? adhanSound;
      adhanVoice = p.getString(_kAdhanVoice) ?? adhanVoice;
    } catch (_) {
      // defaults are fine
    }
  }

  void _changed() {
    notifyListeners();
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      await (_prefs ??= await SharedPreferences.getInstance()).setBool(key, value);
    } catch (_) {}
  }

  void setFollowDevice(bool v) {
    followDevice = v;
    _changed();
    _saveBool(_kFollow, v);
  }

  void setDarkMode(bool v) {
    darkMode = v;
    _changed();
    _saveBool(_kDark, v);
  }

  void setLanguage(String code) {
    languageCode = code;
    _changed();
    _prefsSafe((p) => p.setString(_kLang, code));
  }

  void setFontScale(double v) {
    fontScale = v.clamp(minFontScale, maxFontScale);
    _changed();
    _prefsSafe((p) => p.setDouble(_kFont, fontScale));
  }

  void setNotifications(bool v) {
    notifications = v;
    _changed();
    _saveBool(_kNotif, v);
  }

  void setVibration(bool v) {
    vibration = v;
    _changed();
    _saveBool(_kVibrate, v);
  }

  void setAzkarMorning(bool v) {
    azkarMorning = v;
    _changed();
    _saveBool(_kMorning, v);
  }

  void setAzkarEvening(bool v) {
    azkarEvening = v;
    _changed();
    _saveBool(_kEvening, v);
  }

  void setAdhanSound(bool v) {
    adhanSound = v;
    _changed();
    _saveBool(_kAdhanSound, v);
  }

  void setAdhanVoice(String id) {
    adhanVoice = id;
    _changed();
    _prefsSafe((p) => p.setString(_kAdhanVoice, id));
  }

  Future<void> _prefsSafe(Future<bool> Function(SharedPreferences p) op) async {
    try {
      await op(_prefs ??= await SharedPreferences.getInstance());
    } catch (_) {}
  }

  /// Changes that need the phone's reminders to be created again.
  String get reminderSignature =>
      '$notifications|$vibration|$azkarMorning|$azkarEvening|$languageCode|'
      '$adhanSound|$adhanVoice';
}
