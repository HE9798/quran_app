import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// Arabic Quran / hadith text. Use inside a Directionality(rtl) or with
  /// textDirection: TextDirection.rtl.
  static TextStyle arabic({double size = 24, double height = 1.9, Color? color}) {
    return GoogleFonts.amiri(fontSize: size, height: height, color: color);
  }

  /// Applies Plus Jakarta Sans to every text style.
  ///
  /// We do NOT use GoogleFonts.plusJakartaSansTextTheme() because some
  /// google_fonts versions use a different TextTheme class than your Flutter
  /// SDK (flutter/material vs material_ui), which causes the
  /// "argument type 'TextTheme' can't be assigned" build error.
  /// TextStyle is the same type in both, so this works with any version.
  static TextTheme _withFont(TextTheme t) {
    TextStyle? f(TextStyle? s) => GoogleFonts.plusJakartaSans(textStyle: s);
    return t.copyWith(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final palette = isLight ? AppPalette.light : AppPalette.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? const Color(0xFF0B7A52) : const Color(0xFF34D399),
      onPrimary: isLight ? Colors.white : const Color(0xFF06281B),
      secondary: isLight ? const Color(0xFF0B7A52) : const Color(0xFF34D399),
      onSecondary: isLight ? Colors.white : const Color(0xFF06281B),
      error: isLight ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
      onError: isLight ? Colors.white : const Color(0xFF601410),
      surface: isLight ? Colors.white : const Color(0xFF0A1A2A),
      onSurface: isLight ? const Color(0xFF0E2A21) : const Color(0xFFE6F2EE),
      outline: palette.border,
      // Without these two, tonal buttons got a white icon on a white
      // background in light mode (icon looked missing).
      secondaryContainer: palette.primarySoft,
      onSecondaryContainer: palette.onPrimarySoft,
    );

    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: scheme,
    );

    final textTheme = _withFont(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      dividerColor: palette.border,
      extensions: <ThemeExtension<dynamic>>[palette],
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primarySoft,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? scheme.primary : palette.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? palette.onPrimarySoft : palette.muted,
          );
        }),
      ),
    );
  }
}
