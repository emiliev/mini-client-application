import 'dart:async';

import 'package:flutter/material.dart' show BackButton;
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
    this.outerNavigator,
    super.key,
  });

  final ChildDIContainer container;

  /// The flow's state controller, for the test hook (`testing.dart`).
  final FeatureFlowController<Object?>? controller;

  /// The navigator the flow itself sits in (the app's, when it was pushed from
  /// another screen); null when the flow is not inside a navigator.
  final NavigatorState? outerNavigator;

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

/// The back button of a flow's root page: `AppBar(leading: const
/// McFlowBackButton())`.
///
/// A flow has its own navigator, so its root page never gets `AppBar`'s
/// automatic back button, and iOS has no system back key. This button decides
/// for itself every time it builds: it pops the flow (the navigator the flow
/// sits in) when its own route is the flow's first route and that navigator
/// can pop, and is empty otherwise (the flow is the app's root).
///
/// Use it on the root page only. A page pushed inside the flow keeps the
/// `AppBar`'s automatic back button, which pops that page; this widget would
/// replace it with nothing.
class McFlowBackButton extends StatelessWidget {
  const McFlowBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final outer = FlowScope.read(context).outerNavigator;
    final isFlowRoot = ModalRoute.of(context)?.isFirst ?? false;
    if (!isFlowRoot || outer == null || !outer.canPop()) {
      return const SizedBox.shrink();
    }
    return BackButton(onPressed: () => unawaited(outer.maybePop()));
  }
}
