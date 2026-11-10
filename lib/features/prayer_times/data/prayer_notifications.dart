import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_models.dart';

/// Schedules one phone notification per switched-on prayer for every day we
/// have times for. The notifications are created by the system, so they ring
/// even when the app is closed.
class PrayerNotifications {
  PrayerNotifications._();
  static final instance = PrayerNotifications._();

  static const _channelId = 'prayer_times';
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

  /// Replaces all reminders with the ones for [enabled] prayers.
  Future<void> reschedule(PrayerSchedule schedule, Set<Prayer> enabled) async {
    await init();
    await _plugin.cancelAll();
    if (enabled.isEmpty) return;

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

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Prayer times',
        channelDescription: 'Reminders when it is time to pray',
        importance: Importance.high,
        priority: Priority.high,
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
          title: prayer.english,
          body: prayer == Prayer.sunrise
              ? 'The sun is rising'
              : "It's time for ${prayer.english} prayer",
          scheduledDate: time,
          notificationDetails: details,
          androidScheduleMode: mode,
        );
        count++;
      }
    }
  }
}
