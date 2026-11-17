import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/tr.dart' show toArabicDigits;
import '../../athkar/data/athkar_models.dart';
import '../../athkar/data/athkar_progress_store.dart';
import 'adhan_voices.dart';
import 'prayer_models.dart';

/// Schedules one phone notification per switched-on prayer for every day we
/// have times for. The notifications are created by the system, so they ring
/// even when the app is closed.
class PrayerNotifications {
  PrayerNotifications._();
  static final instance = PrayerNotifications._();

  static const _askedExactKey = 'asked_exact_alarm_v1';
  static const _maxScheduled = 200; // Android keeps up to 500

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Android 13+ asks the user. Returns false when they say no.
  Future<bool> requestPermission() async {
    await init();
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Notification settings for a prayer, using the chosen adhan voice
  /// (or no sound when the adhan is muted). A channel's sound can't change
  /// after it is created, so every voice has its own channel.
  NotificationDetails _adhanDetails({
    required bool fajr,
    String? voiceId,
    bool? forceSound,
  }) {
    final s = AppSettings.instance;
    final arabic = s.isArabic;
    final vibrate = s.vibration;
    final sound = forceSound ?? s.adhanSound;
    final v = vibrate ? 'v' : 's';

    if (!sound) {
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'prayer_mute_$v',
          arabic ? 'الصلاة (بدون صوت)' : 'Prayer (silent)',
          channelDescription: arabic
              ? 'تنبيه الصلاة بدون صوت الأذان'
              : 'Prayer reminders without the adhan sound',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
          enableVibration: vibrate,
        ),
      );
    }

    final voice = AdhanVoice.byId(voiceId ?? s.adhanVoice);
    final res = fajr ? voice.fajrRes : voice.regularRes;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan2_${res}_$v',
        arabic ? 'الأذان · ${voice.arabic}' : 'Adhan · ${voice.english}',
        channelDescription: arabic
            ? 'أذان عند دخول وقت الصلاة'
            : 'The adhan when it is time to pray',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(res),
        // plays at the ALARM volume (usually louder than notification volume)
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: vibrate,
      ),
    );
  }

  /// Shows a notification now so the user can hear [voiceId] exactly as it
  /// will sound at prayer time.
  Future<bool> testAdhan(String voiceId, {required bool fajr}) async {
    if (!await requestPermission()) return false;
    final arabic = AppSettings.instance.isArabic;
    final voice = AdhanVoice.byId(voiceId);
    await _plugin.show(
      id: 99999,
      title: arabic ? 'تجربة الأذان' : 'Adhan test',
      body: voice.label(arabic),
      notificationDetails: _adhanDetails(
        fajr: fajr,
        voiceId: voiceId,
        forceSound: true,
      ),
    );
    return true;
  }

  static int _missedMorningId(DateTime date) =>
      60000000 +
      ((date.year % 100) * 10000 + date.month * 100 + date.day) * 10 +
      3;

  /// The morning azkar were finished: remove today's "unfinished" reminder.
  Future<void> cancelMorningMissedToday() async {
    await init();
    await _plugin.cancel(id: _missedMorningId(DateTime.now()));
  }

  /// Replaces all reminders with the ones for [enabled] prayers.
  Future<void> reschedule(PrayerSchedule schedule, Set<Prayer> enabled) async {
    await init();
    await _plugin.cancelAll();
    final settings = AppSettings.instance;
    if (!settings.notifications) return; // master switch is off
    final wantAzkar =
        settings.azkarMorning || settings.azkarEvening || settings.morningMissed;
    if (enabled.isEmpty && !wantAzkar) return;
    final arabic = settings.isArabic;
    final vibrate = settings.vibration;

    // Exact alarms keep the reminder on the minute. Android 12+ makes the
    // user allow this once in settings; until then we use the inexact mode
    // (can be a few minutes late).
    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    final android = _android;
    if (android != null) {
      var canExact = await android.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        final prefs = await SharedPreferences.getInstance();
        if (!(prefs.getBool(_askedExactKey) ?? false)) {
          await prefs.setBool(_askedExactKey, true); // ask only once
          await android.requestExactAlarmsPermission();
          canExact = await android.canScheduleExactNotifications() ?? false;
        }
      }
      if (canExact) mode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    // A channel's vibration can't be changed once it exists, so each
    // vibration choice has its own channel.
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        vibrate ? 'prayer_times_vibrate' : 'prayer_times_silent',
        arabic ? 'مواقيت الصلاة' : 'Prayer times',
        channelDescription: arabic
            ? 'تنبيه عند دخول وقت الصلاة'
            : 'Reminders when it is time to pray',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: vibrate,
      ),
    );
    // Fajr has its own adhan; sunrise is not a prayer, so it keeps the
    // normal phone sound.
    final regularDetails = _adhanDetails(fajr: false);
    final fajrDetails = _adhanDetails(fajr: true);
    final azkarDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        vibrate ? 'azkar_vibrate' : 'azkar_silent',
        arabic ? 'الأذكار' : 'Azkar',
        channelDescription: arabic
            ? 'تنبيه أذكار الصباح والمساء'
            : 'Morning and evening azkar reminders',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: vibrate,
      ),
    );

    final now = DateTime.now();
    var count = 0;
    for (final day in schedule.days) {
      for (final prayer in Prayer.values) {
        if (!enabled.contains(prayer)) continue;
        final time = day.times[prayer];
        if (time == null || !time.isAfter(now)) continue;
        if (count >= _maxScheduled) return;

        // unique id per day + prayer, e.g. 26 11 10 + index
        final id = ((day.date.year % 100) * 10000 +
                day.date.month * 100 +
                day.date.day) *
            10 +
            prayer.index;

        await _plugin.zonedSchedule(
          id: id,
          title: arabic ? prayer.arabic : prayer.english,
          body: prayer == Prayer.sunrise
              ? (arabic ? 'الشمس تشرق الآن' : 'The sun is rising')
              : (arabic
                  ? 'حان وقت صلاة ${prayer.arabic}'
                  : "It's time for ${prayer.english} prayer"),
          scheduledDate: time,
          notificationDetails: prayer == Prayer.sunrise
              ? details
              : (prayer == Prayer.fajr ? fajrDetails : regularDetails),
          androidScheduleMode: mode,
        );
        count++;
      }

      // ---- azkar: 10 minutes after the window opens, with its end time.
      // morning = Fajr -> Sunrise, evening = Asr -> Maghrib
      Future<void> azkar(int kind, Prayer from, Prayer to, bool morning) async {
        final start = day.times[from];
        final end = day.times[to];
        if (start == null || end == null) return;
        var at = start.add(const Duration(minutes: 10));
        if (!at.isBefore(end)) at = start; // very short window
        if (!at.isAfter(now) || count >= _maxScheduled) return;
        final id = 50000000 +
            ((day.date.year % 100) * 10000 +
                    day.date.month * 100 +
                    day.date.day) *
                10 +
            kind;
        final until = arabic
            ? toArabicDigits(
                '${end.hour % 12 == 0 ? 12 : end.hour % 12}:${end.minute.toString().padLeft(2, '0')} ${end.hour < 12 ? 'ص' : 'م'}')
            : formatClock(end);
        await _plugin.zonedSchedule(
          id: id,
          title: morning
              ? (arabic ? 'أذكار الصباح' : 'Morning azkar')
              : (arabic ? 'أذكار المساء' : 'Evening azkar'),
          body: arabic
              ? 'حان وقت الأذكار · متاحة حتى $until'
              : "It's time for your azkar · until $until",
          scheduledDate: at,
          notificationDetails: azkarDetails,
          androidScheduleMode: mode,
        );
        count++;
      }

      // ---- unfinished morning azkar: 30 minutes before the evening azkar
      // (which open at Asr). Skipped for today when they are already done.
      Future<void> missedMorning() async {
        final asr = day.times[Prayer.asr];
        if (asr == null) return;
        final at = asr.subtract(const Duration(minutes: 30));
        if (!at.isAfter(now) || count >= _maxScheduled) return;
        final isToday = day.date.year == now.year &&
            day.date.month == now.month &&
            day.date.day == now.day;
        if (isToday && AthkarProgressStore.instance.isDoneToday(AthkarSet.morning)) {
          return;
        }
        await _plugin.zonedSchedule(
          id: _missedMorningId(day.date),
          title: arabic ? 'أذكار الصباح لم تكتمل' : 'Morning azkar not finished',
          body: arabic
              ? 'تبقّى ٣٠ دقيقة على أذكار المساء. أكمل أذكار الصباح الآن.'
              : 'Evening azkar start in 30 minutes. Finish your morning azkar now.',
          scheduledDate: at,
          notificationDetails: azkarDetails,
          androidScheduleMode: mode,
        );
        count++;
      }

      if (settings.morningMissed) await missedMorning();

      if (settings.azkarMorning) {
        await azkar(1, Prayer.fajr, Prayer.sunrise, true);
      }
      if (settings.azkarEvening) {
        await azkar(2, Prayer.asr, Prayer.maghrib, false);
      }
    }
  }
}
