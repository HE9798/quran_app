import '../../core/settings/app_settings.dart';
import '../../core/settings/tr.dart';
import '../athkar/data/athkar_models.dart';
import '../athkar/data/athkar_progress_store.dart';
import '../prayer_times/data/prayer_models.dart';
import '../prayer_times/prayer_controller.dart';
import 'companion_widget.dart';
import 'data/companion_store.dart';

/// Plans the companion's speech bubbles on the phone:
///  - 10 minutes before each prayer, and at prayer time (for silent phones)
///  - unfinished azkar (the same times as the azkar reminders)
class CompanionBubbles {
  CompanionBubbles._();

  /// Plans again from the prayer times the app already has.
  static Future<void> resync() async {
    final schedule = PrayerController.instance.schedule;
    await sync(schedule);
  }

  static Future<void> sync(PrayerSchedule? schedule) async {
    await CompanionStore.instance.pushStrings(); // phrases in the current language
    // companion off, or no times yet: nothing planned
    if (!CompanionStore.instance.active || schedule == null) {
      await CompanionWidget.scheduleBubbles(const []);
      return;
    }

    final settings = AppSettings.instance;
    final ar = settings.isArabic;
    String n(num v) => ar ? toArabicDigits('$v') : '$v';

    final events = <({int id, int at, String text})>[];
    final now = DateTime.now();
    // a week ahead: the phone side keeps the list and plans it again after a
    // restart, so the bubbles keep coming even if the app is not opened
    final horizon = now.add(const Duration(days: 7));

    int idFor(DateTime date, int slot) =>
        70000000 + ((date.year % 100) * 10000 + date.month * 100 + date.day) * 100 + slot;

    for (var d = 0; d < schedule.days.length; d++) {
      final day = schedule.days[d];
      if (day.date.isAfter(horizon)) break;

      var slot = 0;
      for (final prayer in Prayer.values) {
        if (!prayer.isPrayer) continue;
        final time = day.times[prayer];
        slot += 2;
        if (time == null) continue;
        final name = prayer.label(ar);

        final before = time.subtract(const Duration(minutes: 10));
        if (before.isAfter(now)) {
          events.add((
            id: idFor(day.date, slot),
            at: before.millisecondsSinceEpoch,
            text: ar ? 'صلاة $name بعد ${n(10)} دقائق' : '$name prayer in 10 minutes',
          ));
        }
        if (time.isAfter(now)) {
          events.add((
            id: idFor(day.date, slot + 1),
            at: time.millisecondsSinceEpoch,
            text: ar ? 'حان وقت صلاة $name' : "It's time for $name prayer",
          ));
        }
      }

      // ---- unfinished azkar: 30 minutes before the other list opens
      if (settings.azkarMissed) {
        final isToday = day.date.year == now.year &&
            day.date.month == now.month &&
            day.date.day == now.day;

        final asr = day.times[Prayer.asr];
        if (asr != null) {
          final at = asr.subtract(const Duration(minutes: 30));
          final done = isToday && AthkarProgressStore.instance.isDoneToday(AthkarSet.morning);
          if (at.isAfter(now) && !done) {
            events.add((
              id: idFor(day.date, 90),
              at: at.millisecondsSinceEpoch,
              text: ar ? 'لا تنسَ أذكار الصباح' : "Don't forget your morning azkar",
            ));
          }
        }
        final next = d + 1 < schedule.days.length ? schedule.days[d + 1].times[Prayer.fajr] : null;
        if (next != null) {
          final at = next.subtract(const Duration(minutes: 30));
          final done = isToday && AthkarProgressStore.instance.isDoneToday(AthkarSet.evening);
          if (at.isAfter(now) && !done) {
            events.add((
              id: idFor(day.date, 91),
              at: at.millisecondsSinceEpoch,
              text: ar ? 'لا تنسَ أذكار المساء' : "Don't forget your evening azkar",
            ));
          }
        }
      }
    }

    events.sort((a, b) => a.at.compareTo(b.at));
    await CompanionWidget.scheduleBubbles(events.take(100).toList());
  }
}
