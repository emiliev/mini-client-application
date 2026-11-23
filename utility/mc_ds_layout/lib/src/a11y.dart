import 'package:flutter/widgets.dart';

/// Accessibility helpers shared by every design-system widget.
abstract final class McA11y {
  /// True when the user asked the OS to reduce motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [normal], or [Duration.zero] under reduced motion.
  static Duration duration(BuildContext context, Duration normal) =>
      reduceMotion(context) ? Duration.zero : normal;

  /// True when the user asked for higher contrast.
  static bool highContrast(BuildContext context) =>
      MediaQuery.highContrastOf(context);
}
