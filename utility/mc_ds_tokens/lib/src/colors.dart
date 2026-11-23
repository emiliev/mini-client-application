import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show immutable;

/// The three palettes the design system ships.
enum McThemeVariant { light, dark, highContrast, highContrastDark }

/// A complete, immutable colour palette. Widgets read it through the theme
/// extension in `mc_ds_theme`; they never hard-code colours.
@immutable
class McPalette {
  const McPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.error,
    required this.onError,
    required this.success,
  });

  final Brightness brightness;
  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color outline;
  final Color error;
  final Color onError;
  final Color success;

  static const McPalette light = McPalette(
    brightness: Brightness.light,
    primary: Color(0xFFB3131B),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFF6F6F7),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFE9E9EC),
    onSurface: Color(0xFF16161A),
    onSurfaceMuted: Color(0xFF5A5A63),
    outline: Color(0xFF8E8E98),
    error: Color(0xFFB00020),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF1B7F3B),
  );

  static const McPalette dark = McPalette(
    brightness: Brightness.dark,
    primary: Color(0xFFFF6B70),
    onPrimary: Color(0xFF2A0004),
    background: Color(0xFF0E0E10),
    surface: Color(0xFF1A1A1E),
    surfaceVariant: Color(0xFF2A2A30),
    onSurface: Color(0xFFF2F2F5),
    onSurfaceMuted: Color(0xFFB4B4BE),
    outline: Color(0xFF7C7C88),
    error: Color(0xFFFF8A9A),
    onError: Color(0xFF3A0010),
    success: Color(0xFF5BD083),
  );

  /// Maximum contrast: at least 7:1 for every text pair.
  static const McPalette highContrast = McPalette(
    brightness: Brightness.light,
    primary: Color(0xFF8A0008),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDEDED),
    onSurface: Color(0xFF000000),
    onSurfaceMuted: Color(0xFF2B2B2B),
    outline: Color(0xFF000000),
    error: Color(0xFF8C0000),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF004D1A),
  );

  /// Maximum contrast on black: at least 7:1 for every text pair.
  static const McPalette highContrastDark = McPalette(
    brightness: Brightness.dark,
    primary: Color(0xFFFFB3B6),
    onPrimary: Color(0xFF000000),
    background: Color(0xFF000000),
    surface: Color(0xFF000000),
    surfaceVariant: Color(0xFF1F1F1F),
    onSurface: Color(0xFFFFFFFF),
    onSurfaceMuted: Color(0xFFE6E6E6),
    outline: Color(0xFFFFFFFF),
    error: Color(0xFFFFB4BE),
    onError: Color(0xFF000000),
    success: Color(0xFF9CFFB8),
  );

  static McPalette of(McThemeVariant variant) => switch (variant) {
    McThemeVariant.light => light,
    McThemeVariant.dark => dark,
    McThemeVariant.highContrast => highContrast,
    McThemeVariant.highContrastDark => highContrastDark,
  };

  /// Interpolates every colour; brightness switches at the midpoint.
  static McPalette lerp(McPalette a, McPalette b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return McPalette(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      primary: c(a.primary, b.primary),
      onPrimary: c(a.onPrimary, b.onPrimary),
      background: c(a.background, b.background),
      surface: c(a.surface, b.surface),
      surfaceVariant: c(a.surfaceVariant, b.surfaceVariant),
      onSurface: c(a.onSurface, b.onSurface),
      onSurfaceMuted: c(a.onSurfaceMuted, b.onSurfaceMuted),
      outline: c(a.outline, b.outline),
      error: c(a.error, b.error),
      onError: c(a.onError, b.onError),
      success: c(a.success, b.success),
    );
  }
}
