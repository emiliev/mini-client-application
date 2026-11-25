import 'package:flutter/widgets.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';

/// The child DI container of one [FeatureFlow] instance, published to the
/// pages below it.
class FlowScope extends InheritedWidget {
  const FlowScope({
    required this.container,
    required super.child,
    this.controller,
    super.key,
  });

  final ChildDIContainer container;

  /// The flow's state controller, for the test hook (`testing.dart`).
  final FeatureFlowController<Object?>? controller;

  /// The nearest scope without depending on it: the flow's container never
  /// changes while its scope lives, so a lookup in a lifecycle that cannot
  /// rebuild (`BlocProvider.create`) needs no dependency.
  static FlowScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FlowScope>();
    if (scope == null) {
      throw _notBelowFlow();
    }
    return scope;
  }

  static FlowScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FlowScope>();
    if (scope == null) {
      throw _notBelowFlow();
    }
    return scope;
  }

  static FlutterError _notBelowFlow() => FlutterError(
    'context.di<T>() was called with a context that is not below a '
    'FeatureFlow. Pages and blocs resolve their dependencies from the '
    'flow they belong to.',
  );

  @override
  bool updateShouldNotify(FlowScope oldWidget) =>
      container != oldWidget.container;
}

extension McFlowContext on BuildContext {
  /// Resolves [T] from the nearest flow's own container (R17). The one call
  /// site for dependencies in UI code, normally in `BlocProvider.create`.
  ///
  /// Non-listening: it registers no dependency on the scope, so it is legal
  /// where listening is forbidden (`BlocProvider.create`), and a rebuild of
  /// the scope does not rebuild the caller.
  T di<T extends Object>({dynamic parameter, String? name}) =>
      FlowScope.read(this).container<T>(parameter: parameter, name: name);

  /// Test aid: resolves every registration of the nearest flow's container.
  /// Fails naming the registered type and its missing dependency.
  Future<void> debugResolveAll() =>
      FlowScope.read(this).container.debugResolveAll();
}
