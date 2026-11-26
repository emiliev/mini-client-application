import 'dart:async';

import 'package:flutter/material.dart'
    show BackButton, CloseButton, DrawerButton, Scaffold;
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

/// The `leading` of a flow page's `AppBar`: `AppBar(leading: const
/// McFlowBackButton())`. Safe on every page of a flow.
///
/// A flow has its own navigator, so its root page never gets `AppBar`'s
/// automatic back button, and iOS has no system back key. This widget decides
/// for itself every time it builds:
/// - On the flow's first route it is a `BackButton` that pops the flow (the
///   navigator the flow sits in), when that navigator can pop.
/// - On any other route it renders what `AppBar` would have shown itself: a
///   `DrawerButton` when the `Scaffold` has a drawer, else a `BackButton`
///   (`CloseButton` for a fullscreen dialog) that pops that page, when it can.
/// - Otherwise it is empty.
///
/// When the flow is the app's root (nothing to leave), a page without a drawer
/// gets an empty leading slot: `AppBar` still reserves its 56 px, so the title
/// stays centred on iOS, which is the layout the app wants (F-0035). It is not
/// worked around.
class McFlowBackButton extends StatelessWidget {
  const McFlowBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) {
      return const SizedBox.shrink();
    }
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    if (route.isFirst) {
      final outer = FlowScope.read(context).outerNavigator;
      if (outer != null && outer.canPop()) {
        return BackButton(onPressed: () => unawaited(outer.maybePop()));
      }
      return hasDrawer ? const DrawerButton() : const SizedBox.shrink();
    }
    if (hasDrawer) {
      return const DrawerButton();
    }
    if (route.impliesAppBarDismissal && route.canPop) {
      return route is PageRoute && route.fullscreenDialog
          ? const CloseButton()
          : const BackButton();
    }
    return const SizedBox.shrink();
  }
}
