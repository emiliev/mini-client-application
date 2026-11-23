import 'package:flutter/painting.dart';

/// The bundled font family (Inter, SIL OFL 1.1; see the `mc_ds_theme` README).
const String mcFontFamily = 'Inter';

/// The package whose pubspec declares [mcFontFamily]. Flutter registers a
/// package font as `packages/<package>/<family>`.
const String mcFontPackage = 'mc_ds_theme';

/// The family name the engine resolves for every `McTypeScale` style. Anything
/// that registers the font by hand (golden harness) must use exactly this.
const String mcResolvedFontFamily = 'packages/$mcFontPackage/$mcFontFamily';

/// Type scale. Colour is applied by the theme, never here.
abstract final class McTypeScale {
  static const TextStyle display = TextStyle(
    fontFamily: mcFontFamily,
    package: mcFontPackage,
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle title = TextStyle(
    fontFamily: mcFontFamily,
    package: mcFontPackage,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: mcFontFamily,
    package: mcFontPackage,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontFamily: mcFontFamily,
    package: mcFontPackage,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle label = TextStyle(
    fontFamily: mcFontFamily,
    package: mcFontPackage,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: mcFontFamily,
    package: mcFontPackage,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
}
