import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Spacing scale (logical pixels, 4-pt grid).
abstract final class McSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii.
abstract final class McRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 16;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Elevation levels (Material elevation values).
abstract final class McElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 8;
}

/// Motion durations and curves. Reduced-motion callers use [Duration.zero].
abstract final class McMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 350);
  static const Curve standard = Curves.easeInOut;
}

/// The minimum interactive size (Apple HIG: 44 pt).
const double mcMinTapTarget = 44;
