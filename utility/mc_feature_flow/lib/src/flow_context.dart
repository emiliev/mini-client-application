import 'package:flutter/widgets.dart';
import 'package:mc_di/mc_di.dart';

/// The child DI container of one [FeatureFlow] instance, published to the
/// pages below it.
class FlowScope extends InheritedWidget {
  const FlowScope({required this.container, required super.child, super.key});

  final ChildDIContainer container;

  static FlowScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FlowScope>();
    if (scope == null) {
      throw FlutterError(
        'context.di<T>() was called with a context that is not below a '
        'FeatureFlow. Pages and blocs resolve their dependencies from the '
        'flow they belong to.',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(FlowScope oldWidget) =>
      container != oldWidget.container;
}

extension McFlowContext on BuildContext {
  /// Resolves [T] from the nearest flow's own container (R17). The one call
  /// site for dependencies in UI code, normally in `BlocProvider.create`.
  T di<T extends Object>({dynamic parameter, String? name}) =>
      FlowScope.of(this).container<T>(parameter: parameter, name: name);

  /// Test aid: resolves every registration of the nearest flow's container.
  /// Fails naming the registered type and its missing dependency.
  Future<void> debugResolveAll() =>
      FlowScope.of(this).container.debugResolveAll();
}
