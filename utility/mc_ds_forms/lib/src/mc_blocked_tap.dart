import 'package:flutter/material.dart';

/// Makes a disabled button tappable for feedback: it stays disabled (to touch
/// and to screen readers, with [hint] saying what is missing), but a tap
/// calls [onTap]. Does nothing unless [active].
class McBlockedTap extends StatelessWidget {
  const McBlockedTap({
    required this.active,
    required this.onTap,
    required this.label,
    required this.hint,
    required this.child,
    super.key,
  });

  final bool active;
  final VoidCallback? onTap;
  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return child;
    }
    return Semantics(
      container: true,
      button: true,
      enabled: false,
      label: label,
      hint: hint,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
