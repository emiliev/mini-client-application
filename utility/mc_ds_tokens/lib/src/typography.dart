import 'package:flutter/painting.dart';

/// The bundled font family (Inter, SIL OFL 1.1; see the `mc_ds_theme` README).
const String mcFontFamily = 'Inter';

/// Type scale. Colour is applied by the theme, never here.
abstract final class McTypeScale {
  static const TextStyle display = TextStyle(
    fontFamily: mcFontFamily,
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle title = TextStyle(
    fontFamily: mcFontFamily,
    fontSize: 22,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: mcFontFamily,
    fontSize: 17,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontFamily: mcFontFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle label = TextStyle(
    fontFamily: mcFontFamily,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: mcFontFamily,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );
}
