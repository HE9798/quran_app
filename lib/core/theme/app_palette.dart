import 'package:flutter/material.dart';

/// Extra design tokens that don't fit into Material's ColorScheme.
/// Values come straight from the Figma-style design (light and dark).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.surface,
    required this.surfaceAlt,
    required this.muted,
    required this.border,
    required this.primarySoft,
    required this.onPrimarySoft,
    required this.hero,
  });

  /// Cards and inputs (design token: sf)
  final Color surface;

  /// Segmented controls, tracks (sf2)
  final Color surfaceAlt;

  /// Secondary text (mu)
  final Color muted;

  /// Card borders and dividers (bd)
  final Color border;

  /// Soft green tint for selected items and icon tiles (ps)
  final Color primarySoft;

  /// Text/icons placed on [primarySoft] (pst)
  final Color onPrimarySoft;

  /// Big green card background (hero)
  final Color hero;

  static const light = AppPalette(
    surface: Color(0xFFF4F8F6),
    surfaceAlt: Color(0xFFE4F1EA),
    muted: Color(0xFF566B62),
    border: Color(0xFFDFE9E4),
    primarySoft: Color(0xFFE3F3EB),
    onPrimarySoft: Color(0xFF086043),
    hero: Color(0xFF0B7A52),
  );

  static const dark = AppPalette(
    surface: Color(0xFF11273A),
    surfaceAlt: Color(0xFF183449),
    muted: Color(0xFF9AB3AB),
    border: Color(0xFF264760),
    primarySoft: Color(0xFF123A38),
    onPrimarySoft: Color(0xFF6EE7B7),
    hero: Color(0xFF0E6B4C),
  );

  @override
  AppPalette copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? muted,
    Color? border,
    Color? primarySoft,
    Color? onPrimarySoft,
    Color? hero,
  }) {
    return AppPalette(
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimarySoft: onPrimarySoft ?? this.onPrimarySoft,
      hero: hero ?? this.hero,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimarySoft: Color.lerp(onPrimarySoft, other.onPrimarySoft, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  /// Usage: `context.palette.surface`
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
