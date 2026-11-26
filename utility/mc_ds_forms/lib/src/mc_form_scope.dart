import 'package:flutter/widgets.dart';

/// Tells the form fields below it whether they accept input. A busy
/// `McFormScaffold` and a disabled `McFieldGroup` switch it off; a nested
/// scope can only narrow it, never widen it.
class McFormScope extends InheritedWidget {
  const McFormScope({required this.enabled, required super.child, super.key});

  final bool enabled;

  /// False when any enclosing scope is disabled; true without a scope.
  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<McFormScope>()?.enabled ??
      true;

  /// A scope for [child] that is enabled only if [enabled] and the scope
  /// above it are.
  static Widget narrow(
    BuildContext context, {
    required bool enabled,
    required Widget child,
  }) => McFormScope(enabled: enabled && enabledOf(context), child: child);

  @override
  bool updateShouldNotify(McFormScope old) => enabled != old.enabled;
}
