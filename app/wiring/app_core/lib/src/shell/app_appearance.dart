import 'package:flutter/material.dart';
import 'package:mc_appearance/mc_appearance.dart';

/// How the app shows the user's appearance (ADR-0013). `mc_appearance` is
/// pure Dart; these are its Flutter meanings, in one place.
extension McAppearanceFlutter on AppearancePreferences {
  /// `MaterialApp.themeMode`: System follows the platform's brightness.
  ThemeMode get flutterThemeMode => switch (themeMode) {
    AppearanceThemeMode.system => ThemeMode.system,
    AppearanceThemeMode.light => ThemeMode.light,
    AppearanceThemeMode.dark => ThemeMode.dark,
  };

  /// `ThemeData.visualDensity` of every app theme (`McTheme.of`): Compact
  /// tightens Material widgets, and screens read it for their own spacing.
  /// Comfortable keeps the platform's default.
  VisualDensity? get flutterVisualDensity => switch (density) {
    AppearanceDensity.comfortable => null,
    AppearanceDensity.compact => VisualDensity.compact,
  };

  /// [data] with animations off when the user or the platform asked for
  /// reduced motion (`MediaQuery.disableAnimations`, which the design
  /// system's motion reads through `McA11y`). The platform's own setting is
  /// never turned back on.
  MediaQueryData applyMotion(MediaQueryData data) =>
      reduceMotion ? data.copyWith(disableAnimations: true) : data;
}
