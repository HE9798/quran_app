import 'package:timezone/timezone.dart' as tz;

/// The six times shown in the list. Only the five real prayers count as
/// "next prayer" (sunrise is shown, but it is not a prayer).
enum Prayer {
  fajr('Fajr', 'الفجر', 'Fajr'),
  sunrise('Sunrise', 'الشروق', 'Sunrise'),
  dhuhr('Dhuhr', 'الظهر', 'Dhuhr'),
  asr('Asr', 'العصر', 'Asr'),
  maghrib('Maghrib', 'المغرب', 'Maghrib'),
  isha('Isha', 'العشاء', 'Isha');

  const Prayer(this.english, this.arabic, this.apiKey);

  final String english;
  final String arabic;

  /// Key used in the Aladhan "timings" object.
  final String apiKey;

  bool get isPrayer => this != Prayer.sunrise;
}

/// All times of one day. The times are [tz.TZDateTime]s in the time zone of
/// the user's location, so `.hour` / `.minute` are the wall-clock time there.
class PrayerDay {
  const PrayerDay({
    required this.date,
    required this.times,
    required this.hijri,
  });

  /// Calendar date (year, month, day only).
  final DateTime date;
  final Map<Prayer, tz.TZDateTime> times;

  /// e.g. "14 Jumada I 1448"
  final String hijri;
}

/// A run of days (about one to two months), enough for the list, the
/// countdown and for scheduling reminders.
class PrayerSchedule {
  const PrayerSchedule({required this.days, required this.location});

  final List<PrayerDay> days;
  final tz.Location location;
}

/// "2:50 PM", or "2:50" when [withPeriod] is false.
String formatClock(DateTime t, {bool withPeriod = true}) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final period = t.hour < 12 ? 'AM' : 'PM';
  return withPeriod ? '$hour:$minute $period' : '$hour:$minute';
}

/// "in 1h 24m", "in 12m", "now".
String formatCountdown(Duration d) {
  final minutes = (d.inSeconds / 60).ceil();
  if (minutes <= 0) return 'now';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h == 0 ? 'in ${m}m' : 'in ${h}h ${m}m';
}
