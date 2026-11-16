import 'package:flutter/widgets.dart';

/// Arabic-Indic digits: 123 -> ١٢٣
String toArabicDigits(String input) => input.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
    );

/// True when the text contains Arabic letters (used to pick the font and the
/// reading direction of content that can be in either language).
bool hasArabic(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);

const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _monthsAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysAr = [
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];

/// Tiny translation helper: `context.tr('Home', 'الرئيسية')`.
/// Because it reads the app locale, the widget rebuilds when the language
/// changes.
extension TrContext on BuildContext {
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';

  String tr(String en, String ar) => isArabic ? ar : en;

  /// A number in the current language's digits.
  String n(Object value) => isArabic ? toArabicDigits('$value') : '$value';

  /// Any text that contains digits, in the current language's digits.
  String digits(String text) => isArabic ? toArabicDigits(text) : text;

  /// "2:50 PM" / "٢:٥٠ م"
  String clock(DateTime t, {bool withPeriod = true}) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = isArabic ? (t.hour < 12 ? 'ص' : 'م') : (t.hour < 12 ? 'AM' : 'PM');
    return digits(withPeriod ? '$hour:$minute $period' : '$hour:$minute');
  }

  /// "in 1h 24m" / "بعد ١ س ٢٤ د"
  String countdown(Duration d) {
    final minutes = (d.inSeconds / 60).ceil();
    if (minutes <= 0) return tr('now', 'الآن');
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (isArabic) {
      return digits(h == 0 ? 'بعد $m د' : 'بعد $h س $m د');
    }
    return h == 0 ? 'in ${m}m' : 'in ${h}h ${m}m';
  }

  /// A duration without "in": "1h 24m" / "١ س ٢٤ د"
  String span(Duration d) {
    final minutes = (d.inSeconds / 60).ceil().clamp(0, 100000);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (isArabic) return digits(h == 0 ? '$m د' : '$h س $m د');
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }

  /// "Mon, 15 Nov" / "الأحد، ١٥ نوفمبر"
  String dateLine(DateTime d) {
    final weekday = (isArabic ? _weekdaysAr : _weekdaysEn)[d.weekday - 1];
    final month = (isArabic ? _monthsAr : _monthsEn)[d.month - 1];
    return isArabic
        ? digits('$weekday، ${d.day} $month')
        : '$weekday, ${d.day} $month';
  }

  /// "Nov 15" / "١٥ نوفمبر"
  String shortDate(DateTime d) {
    final month = (isArabic ? _monthsAr : _monthsEn)[d.month - 1];
    return isArabic ? digits('${d.day} $month') : '$month ${d.day}';
  }
}
