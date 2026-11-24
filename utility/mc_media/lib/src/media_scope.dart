import 'package:flutter/widgets.dart';
import 'package:mc_media/mc_media.dart';

/// Provides the [McImageResolver] to the widgets below it.
class McMediaScope extends InheritedWidget {
  const McMediaScope({required this.resolver, required super.child, super.key});

  final McImageResolver resolver;

  /// The resolver of the nearest scope. Throws a [FlutterError] naming
  /// `McMediaScope` when there is none.
  static McImageResolver of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<McMediaScope>();
    if (scope == null) {
      throw FlutterError(
        'McMediaScope.of() called with a context that has no McMediaScope '
        'above it.\nWrap the app in McMediaScope(resolver: ...).',
      );
    }
    return scope.resolver;
  }

  @override
  bool updateShouldNotify(McMediaScope oldWidget) =>
      resolver != oldWidget.resolver;
}
