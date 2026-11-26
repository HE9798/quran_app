import 'package:material_ui/material_ui.dart';

import '../settings/tr.dart';
import 'app_theme.dart';

/// Content (hadith, ...) can be Arabic or English depending on the language
/// chosen. These pick the right reading direction and font for a given text.
TextDirection dirFor(String text) =>
    hasArabic(text) ? TextDirection.rtl : TextDirection.ltr;

/// [size] is the Arabic size; English text is set a little smaller because
/// Amiri is a large-looking font.
TextStyle contentStyle(
  String text, {
  required double size,
  double height = 1.6,
  Color? color,
  FontWeight? weight,
}) {
  if (hasArabic(text)) {
    final style = AppTheme.arabic(size: size, height: height, color: color);
    return weight == null ? style : style.copyWith(fontWeight: weight);
  }
  return TextStyle(
    fontSize: size * 0.78,
    height: height < 1.5 ? 1.4 : 1.55,
    color: color,
    fontWeight: weight,
  );
}
