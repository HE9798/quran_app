/// Hijri calendar maths and the list of occasions.
///
/// The conversion is the standard "tabular" calendar (works offline). The real
/// month starts with the moon sighting, so it can be a day away from the
/// official date: the calendar page has a +/- 1 day adjustment for that.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);
  final int year;
  final int month; // 1..12
  final int day; // 1..30
}

class Occasion {
  const Occasion(this.month, this.day, this.en, this.ar,
      {this.headline = true, this.major = false});

  final int month;
  final int day;
  final String en;
  final String ar;

  /// Shown in the "next occasion" card (the small repeating ones are not).
  final bool headline;

  /// Eids and the new year: drawn with a stronger mark.
  final bool major;
}

class HijriCalendar {
  HijriCalendar._();

  static const monthsEn = [
    'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani", 'Jumada al-Ula',
    'Jumada al-Akhirah', 'Rajab', "Sha'ban", 'Ramadan', 'Shawwal',
    "Dhul-Qi'dah", 'Dhul-Hijjah',
  ];
  static const monthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  // ----------------------------------------------------------- the maths

  static int _jdn(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
  }

  static int _islamicToJdn(int y, int m, int d) =>
      d + (29.5 * (m - 1)).ceil() + (y - 1) * 354 + (3 + 11 * y) ~/ 30 + 1948440 - 1;

  /// The Hijri date of a Gregorian day. [adjust] moves it by whole days.
  static HijriDate fromGregorian(DateTime date, {int adjust = 0}) {
    final j = _jdn(date.year, date.month, date.day) + adjust;
    final y = (30 * (j - 1948440) + 10646) ~/ 10631;
    final m = (((j - 29 - _islamicToJdn(y, 1, 1)) / 29.5).ceil() + 1).clamp(1, 12);
    final d = j - _islamicToJdn(y, m, 1) + 1;
    return HijriDate(y, m, d);
  }

  /// The Gregorian day (at noon, so daylight saving cannot move it) of a Hijri date.
  static DateTime toGregorian(int y, int m, int d, {int adjust = 0}) {
    final j = _islamicToJdn(y, m, d) - adjust;
    // JDN -> Gregorian
    final a = j + 32044;
    final b = (4 * a + 3) ~/ 146097;
    final c = a - 146097 * b ~/ 4;
    final dd = (4 * c + 3) ~/ 1461;
    final e = c - 1461 * dd ~/ 4;
    final mm = (5 * e + 2) ~/ 153;
    final day = e - (153 * mm + 2) ~/ 5 + 1;
    final month = mm + 3 - 12 * (mm ~/ 10);
    final year = 100 * b + dd - 4800 + mm ~/ 10;
    return DateTime(year, month, day, 12);
  }

  static int daysInMonth(int y, int m, {int adjust = 0}) {
    final ny = m == 12 ? y + 1 : y;
    final nm = m == 12 ? 1 : m + 1;
    return _islamicToJdn(ny, nm, 1) - _islamicToJdn(y, m, 1);
  }

  /// Whole days from [a] to [b] (calendar days).
  static int daysBetween(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  // ----------------------------------------------------------- occasions

  static const occasions = <Occasion>[
    Occasion(1, 1, 'Islamic New Year', 'رأس السنة الهجرية', major: true),
    Occasion(1, 9, "Tasu'a: the 9th of Muharram (fast it with Ashura)", 'تاسوعاء: التاسع من محرم (يُستحب صيامه مع عاشوراء)'),
    Occasion(1, 10, 'Day of Ashura (a day of fasting)', 'يوم عاشوراء (يُستحب صيامه)'),
    Occasion(3, 12, "The Prophet's birthday (Mawlid)", 'المولد النبوي الشريف'),
    Occasion(7, 27, "Isra and Mi'raj", 'الإسراء والمعراج'),
    Occasion(8, 15, "Mid-Sha'ban", 'ليلة النصف من شعبان'),
    Occasion(9, 1, 'First day of Ramadan', 'أول أيام رمضان', major: true),
    Occasion(9, 21, 'Odd night of the last ten: seek Laylat al-Qadr', 'ليلة وترية من العشر الأواخر: تحرَّ ليلة القدر', headline: false),
    Occasion(9, 23, 'Odd night of the last ten: seek Laylat al-Qadr', 'ليلة وترية من العشر الأواخر: تحرَّ ليلة القدر', headline: false),
    Occasion(9, 25, 'Odd night of the last ten: seek Laylat al-Qadr', 'ليلة وترية من العشر الأواخر: تحرَّ ليلة القدر', headline: false),
    Occasion(9, 27, 'Laylat al-Qadr (most likely night)', 'ليلة القدر (الأرجح)'),
    Occasion(9, 29, 'Odd night of the last ten: seek Laylat al-Qadr', 'ليلة وترية من العشر الأواخر: تحرَّ ليلة القدر', headline: false),
    Occasion(10, 1, 'Eid al-Fitr', 'عيد الفطر المبارك', major: true),
    Occasion(10, 2, 'The six days of Shawwal begin (fast any six days this month)', 'بداية ستٍّ من شوال (صُم ستة أيام في هذا الشهر)', headline: false),
    Occasion(12, 1, 'First ten days of Dhul-Hijjah begin', 'بداية عشر ذي الحجة'),
    Occasion(12, 2, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 3, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 4, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 5, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 6, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 7, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 8, 'First ten days of Dhul-Hijjah', 'من عشر ذي الحجة', headline: false),
    Occasion(12, 9, 'Day of Arafah (a day of fasting)', 'يوم عرفة (يُستحب صيامه لغير الحاج)'),
    Occasion(12, 10, 'Eid al-Adha', 'عيد الأضحى المبارك', major: true),
    Occasion(12, 11, 'Days of Tashreeq', 'أيام التشريق', headline: false),
    Occasion(12, 12, 'Days of Tashreeq', 'أيام التشريق', headline: false),
    Occasion(12, 13, 'Days of Tashreeq', 'أيام التشريق', headline: false),
  ];

  static List<Occasion> on(int month, int day) =>
      [for (final o in occasions) if (o.month == month && o.day == day) o];

  // ------------------------------------------------------- fasting marks

  /// Sunnah fasting days: Mondays, Thursdays and the white days (13, 14, 15).
  /// Never inside Ramadan, on the two Eids or on the days of Tashreeq, where
  /// fasting is not allowed or already obligatory.
  static String? fastingKind(DateTime greg, HijriDate h) {
    if (h.month == 9) return null; // Ramadan
    if (h.month == 10 && h.day == 1) return null; // Eid al-Fitr
    if (h.month == 12 && h.day >= 10 && h.day <= 13) return null; // Eid al-Adha + Tashreeq
    if (h.day >= 13 && h.day <= 15) return 'white';
    if (greg.weekday == DateTime.monday || greg.weekday == DateTime.thursday) return 'weekly';
    return null;
  }
}
