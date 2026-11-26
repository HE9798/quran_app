import 'dart:convert';
import 'dart:ui' show Color, PlatformDispatcher, Brightness;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'
    hide NotificationVisibility; // clashes with flutter_local_notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/tr.dart' show toArabicDigits;
import 'prayer_models.dart';

/// The fixed "next prayer" notification in the phone's status bar.
///
/// It is a foreground service, so Android keeps the app alive in the
/// background. Every 30 seconds the service posts the notification again, so
/// if the user swipes it away it comes back within 30 seconds. The
/// notification is coloured like the app (light = cream, dark = green) and laid
/// out like the prayer card on the home screen.
class PrayerCountdownService {
  PrayerCountdownService._();
  static final instance = PrayerCountdownService._();

  static const serviceId = 7701;
  static const channelId = 'prayer_countdown_fg';

  static const _kTimes = 'cd_times_v1';
  static const _kArabic = 'cd_arabic_v1';
  static const _kDark = 'cd_dark_v1';

  // the app's own colours
  static const _lightBackground = Color(0xFFF7EBD4);
  static const _darkBackground = Color(0xFF12685E); // the app's green

  /// True when the app is showing its dark theme right now.
  static bool appIsDark() {
    final s = AppSettings.instance;
    if (s.followDevice) {
      return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
    return s.darkMode;
  }

  /// Saves the upcoming prayer times for the service, then starts, updates or
  /// stops it according to the settings.
  Future<void> sync(PrayerSchedule schedule) async {
    final settings = AppSettings.instance;
    // Always shown while notifications are on (no separate switch).
    final want = settings.notifications;

    if (!want) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }

    // [[epochMillis, prayerIndex], ...] from the start of today onwards
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final list = <List<int>>[];
    for (final day in schedule.days) {
      for (final prayer in Prayer.values) {
        if (!prayer.isPrayer) continue; // same prayers as the home timer
        final time = day.times[prayer];
        if (time != null && !time.isBefore(startOfToday)) {
          list.add([time.millisecondsSinceEpoch, prayer.index]);
        }
      }
    }
    list.sort((a, b) => a[0].compareTo(b[0]));
    final arabic = settings.isArabic;
    final dark = appIsDark();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTimes, jsonEncode(list));
    await prefs.setBool(_kArabic, arabic);
    await prefs.setBool(_kDark, dark);

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: channelId,
        channelName: arabic ? 'العد التنازلي للصلاة' : 'Prayer countdown',
        channelDescription: arabic
            ? 'يعرض الوقت المتبقي للصلاة القادمة'
            : 'Shows the time left until the next prayer',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    // Android 13+ needs the notification permission, otherwise nothing shows.
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final text = describeNext(list, arabic);
    if (!await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.startService(
        serviceId: serviceId,
        serviceTypes: [ForegroundServiceTypes.specialUse],
        notificationTitle: text.title,
        notificationText: text.body,
        callback: prayerCountdownCallback,
      );
      // the reason is printed in the VS Code Debug Console if it fails
      if (result is ServiceRequestFailure) {
        debugPrint('Prayer countdown could not start: ${result.error}');
      }
    }
    // show it in the app's colours right away (the service does the same
    // every 30 seconds)
    await postStyled(text, dark: dark, arabic: arabic);
  }

  /// Texts for the notification, laid out like the card on the home screen.
  static NextText describeNext(List<List<int>> times, bool arabic) {
    final nowDate = DateTime.now();
    final now = nowDate.millisecondsSinceEpoch;
    for (final t in times) {
      if (t[0] <= now) continue;
      final prayer = Prayer.values[t[1]];
      final at = DateTime.fromMillisecondsSinceEpoch(t[0]);

      final minutes = ((t[0] - now) / 60000).ceil();
      final h = minutes ~/ 60;
      final m = minutes % 60;
      final left = arabic
          ? toArabicDigits(h > 0 ? 'بعد $h س $m د' : 'بعد $m د')
          : (h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m');

      // the day's five prayers, like the row on the home screen
      final row = StringBuffer();
      for (final e in times) {
        final d = DateTime.fromMillisecondsSinceEpoch(e[0]);
        if (d.year != at.year || d.month != at.month || d.day != at.day) {
          continue;
        }
        final p = Prayer.values[e[1]];
        final name = arabic ? p.arabic : p.english;
        final time = _clock(d, arabic, period: false);
        final cell = '$name $time';
        if (row.isNotEmpty) row.write(' &nbsp;·&nbsp; ');
        row.write(e[1] == t[1] && e[0] == t[0] ? '<b>$cell</b>' : cell);
      }

      final name = arabic ? prayer.arabic : prayer.english;
      final nameAndTime = '$name · ${_clock(at, arabic)}';
      // In Arabic every line starts with an RTL mark (U+200F) so Android lays
      // it out right-to-left and aligns it to the right, whatever the phone's
      // own language is.
      final rtl = arabic ? '\u200F' : '';
      return NextText(
        // collapsed: prayer + time, then the countdown
        title: '$rtl$nameAndTime',
        body: '$rtl$left',
        // expanded: Android already shows the app name in the header and the
        // title above, so this holds the countdown and the schedule
        big: '$rtl$left<br><br>$rtl$row',
      );
    }
    return NextText(
      title: arabic ? '\u200Fمواقيت الصلاة' : 'Prayer times',
      body: arabic ? 'افتح التطبيق لتحديث المواقيت' : 'Open the app to refresh the times',
      big: arabic ? 'افتح التطبيق لتحديث المواقيت' : 'Open the app to refresh the times',
    );
  }

  static String _clock(DateTime t, bool arabic, {bool period = true}) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final tail = !period ? '' : (arabic ? (t.hour < 12 ? ' ص' : ' م') : (t.hour < 12 ? ' AM' : ' PM'));
    final text = '$h:$m$tail';
    return arabic ? toArabicDigits(text) : text;
  }

  static FlutterLocalNotificationsPlugin? _plugin;

  /// Posts the notification with the same id as the service's own, so it
  /// replaces it, using the app's colours and a live countdown.
  static Future<void> postStyled(
    NextText text, {
    required bool dark,
    required bool arabic,
  }) async {
    var plugin = _plugin;
    if (plugin == null) {
      plugin = _plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
    }
    await plugin.show(
      id: serviceId,
      title: text.title,
      body: text.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          arabic ? 'العد التنازلي للصلاة' : 'Prayer countdown',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
          // the notification's background takes this colour
          color: dark ? _darkBackground : _lightBackground,
          colorized: true,
          showWhen: false,
          styleInformation: BigTextStyleInformation(
            text.big,
            htmlFormatBigText: true,
          ),
          category: AndroidNotificationCategory.status,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }
}

class NextText {
  const NextText({required this.title, required this.body, required this.big});
  final String title; //  collapsed line 1, e.g. "Dhuhr · 11:41 AM"
  final String body; //   collapsed line 2, e.g. "in 2h 39m"
  final String big; //    expanded: prayer + time, countdown, schedule (HTML)
}

/// Runs inside the service (its own isolate, so it works with the app in the
/// background). Every 30 seconds it posts the notification again.
@pragma('vm:entry-point')
void prayerCountdownCallback() {
  FlutterForegroundTask.setTaskHandler(_PrayerCountdownHandler());
}

class _PrayerCountdownHandler extends TaskHandler {
  Future<void> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // the app may have saved new times
    final raw = prefs.getString('cd_times_v1');
    final arabic = prefs.getBool('cd_arabic_v1') ?? false;
    final dark = prefs.getBool('cd_dark_v1') ?? false;
    final times = <List<int>>[];
    if (raw != null) {
      for (final e in jsonDecode(raw) as List) {
        times.add([(e as List)[0] as int, e[1] as int]);
      }
    }
    await PrayerCountdownService.postStyled(
      PrayerCountdownService.describeNext(times, arabic),
      dark: dark,
      arabic: arabic,
    );
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => _refresh();

  @override
  void onRepeatEvent(DateTime timestamp) {
    _refresh();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
