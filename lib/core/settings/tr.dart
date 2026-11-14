import 'package:flutter/widgets.dart';

/// Tiny translation helper: `context.tr('Home', 'الرئيسية')`.
/// Because it reads the app locale, the widget rebuilds when the language
/// changes.
extension TrContext on BuildContext {
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
  String tr(String en, String ar) => isArabic ? ar : en;
}
