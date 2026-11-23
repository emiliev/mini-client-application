import 'package:flutter/material.dart';
import 'package:mc_ds_theme/src/mc_theme_extension.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Builds the app `ThemeData` for each [McThemeVariant].
abstract final class McTheme {
  static ThemeData get light => of(McThemeVariant.light);
  static ThemeData get dark => of(McThemeVariant.dark);
  static ThemeData get highContrast => of(McThemeVariant.highContrast);
  static ThemeData get highContrastDarkTheme =>
      of(McThemeVariant.highContrastDark);

  /// Picks the variant from platform settings (`MediaQuery.highContrast`).
  static McThemeVariant variantFor({
    required Brightness brightness,
    bool highContrast = false,
  }) {
    if (highContrast) {
      return brightness == Brightness.dark
          ? McThemeVariant.highContrastDark
          : McThemeVariant.highContrast;
    }
    return brightness == Brightness.dark
        ? McThemeVariant.dark
        : McThemeVariant.light;
  }

  static ThemeData of(McThemeVariant variant) {
    final p = McPalette.of(variant);
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.onSurface,
      onSecondary: p.surface,
      error: p.error,
      onError: p.onError,
      surface: p.surface,
      onSurface: p.onSurface,
      surfaceContainerHighest: p.surfaceVariant,
      onSurfaceVariant: p.onSurfaceMuted,
      outline: p.outline,
    );
    final text = _textTheme(p);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: mcFontFamily,
      package: mcFontPackage,
      textTheme: text,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.outline,
      extensions: [McThemeExtension(variant: variant, palette: p)],
    );
  }

  static TextTheme _textTheme(McPalette p) {
    TextStyle s(TextStyle base, [Color? color]) =>
        base.copyWith(color: color ?? p.onSurface);
    return TextTheme(
      displayLarge: s(McTypeScale.display),
      headlineMedium: s(McTypeScale.title),
      titleMedium: s(McTypeScale.headline),
      bodyLarge: s(McTypeScale.body),
      bodyMedium: s(McTypeScale.body),
      labelLarge: s(McTypeScale.label),
      bodySmall: s(McTypeScale.caption, p.onSurfaceMuted),
    );
  }
}
