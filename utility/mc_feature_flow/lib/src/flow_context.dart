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
    this.outerCanPop = false,
    this.flowNavigatorObserver,
    super.key,
  });

  final ChildDIContainer container;

  /// The flow's state controller, for the test hook (`testing.dart`).
  final FeatureFlowController<Object?>? controller;

  /// The navigator the flow itself sits in (the app's, when it was pushed from
  /// another screen); null when the flow is not inside a navigator.
  final NavigatorState? outerNavigator;

  /// Whether the flow's own route has a route below it in [outerNavigator], so
  /// the flow can be left. `FeatureFlow` depends on its outer `ModalRoute` and
  /// republishes this value, so a widget that depends on the scope rebuilds
  /// when the routes below the flow change (a router `go`, a deep-link stack
  /// rebuild, `pushAndRemoveUntil`).
  final bool outerCanPop;

  /// An observer attached to the flow's own navigator, so the scope knows
  /// which `Navigator` is the flow's ([isFlowNavigator]).
  final NavigatorObserver? flowNavigatorObserver;

  /// Whether [navigator] is the flow's own navigator. A scope built without an
  /// observer (a test double) cannot tell and says yes.
  bool isFlowNavigator(NavigatorState? navigator) {
    final observer = flowNavigatorObserver;
    return observer == null || identical(observer.navigator, navigator);
  }

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

  /// The nearest scope, registering a dependency on it, or null outside any
  /// flow.
  static FlowScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FlowScope>();

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
      container != oldWidget.container || outerCanPop != oldWidget.outerCanPop;
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

/// The `leading` of a page's `AppBar`: `AppBar(leading: const
/// McFlowBackButton())`. Safe on every page: inside a flow or not, on a flow's
/// root or on a page pushed inside it, with or without a drawer. It never
/// throws.
///
/// A flow has its own navigator, so its root page never gets `AppBar`'s
/// automatic back button, and iOS has no system back key. This widget decides
/// for itself every time it builds, and it rebuilds when what it decides on
/// changes (the route's own state, and the routes below the flow, which the
/// flow publishes through [FlowScope.outerCanPop]).
///
/// On the root page of a flow (the first route of the flow's navigator), in
/// this order:
/// 1. A local history entry that implies dismissal (`route.willHandlePopInternally`
///    and `route.impliesAppBarDismissal`, for example a `showBottomSheet`): a
///    plain `BackButton`, which removes the entry and stays in the flow. A
///    drawer's own entry does not imply dismissal, so an open drawer does not
///    turn the leading into a back arrow (as in `AppBar`).
/// 2. A drawer: a `DrawerButton`, as `AppBar` does.
/// 3. The flow can be left (a route below it in the outer navigator): a
///    `BackButton` that calls `maybePop` on the outer navigator, so the outer
///    route's `PopScope` is respected.
/// 4. Otherwise it is empty.
///
/// On any other page, and on a first route outside any flow, it renders what
/// `AppBar` would show itself: a `DrawerButton` when the `Scaffold` has a
/// drawer, else a `BackButton` (`CloseButton` for a fullscreen dialog) that
/// pops that page, when it can; otherwise it is empty. Outside any route it is
/// empty.
///
/// When the flow is the app's root and has no drawer, the widget is empty and
/// `AppBar` still reserves its 56 px leading slot. iOS centres titles, so this
/// is the layout the app wants (F-0035). It is not worked around.
class McFlowBackButton extends StatelessWidget {
  const McFlowBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) {
      return const SizedBox.shrink();
    }
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    // The flow-root branch is for the first route of the flow's own
    // navigator; the first route of a navigator nested in a flow page follows
    // the AppBar's default logic.
    final flowScope = route.isFirst ? FlowScope.maybeOf(context) : null;
    final scope =
        flowScope != null && flowScope.isFlowNavigator(route.navigator)
        ? flowScope
        : null;
    if (scope != null) {
      if (route.willHandlePopInternally && route.impliesAppBarDismissal) {
        return const BackButton();
      }
      if (hasDrawer) {
        return const DrawerButton();
      }
      final outer = scope.outerNavigator;
      if (outer != null && scope.outerCanPop) {
        return BackButton(onPressed: () => unawaited(outer.maybePop()));
      }
      return const SizedBox.shrink();
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
