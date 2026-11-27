import 'dart:async';

import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_feature_flow/src/flow_context.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// One page of a flow. [name] is the route name (analytics, restoration).
class McFlowPage {
  const McFlowPage({required this.name, required this.child, this.arguments});

  final String name;
  final Widget child;
  final Object? arguments;
}

/// What the user sees when a flow fails to open; the error itself goes to
/// monitoring only.
const String _loadFailedMessage = 'This could not be loaded. Please try again.';

typedef OnGenerateFlowPages<T> = List<McFlowPage> Function(T state);

/// Intra-feature navigation (Tide's `FeatureFlow`): the pages are a function
/// of the flow state [T], which blocs change through
/// `FeatureFlowController<T>`.
///
/// Each instance owns a child DI container (R17): it forwards [rootImports]
/// from the root, registers its [FeatureFlowController] and then runs
/// [flowInitializer]. An unregistered root import fails fast, naming its type.
/// [provide] registers flow-scoped instances (a navigator the app passes in)
/// in that container before [flowInitializer] runs; they resolve inside the
/// flow and nowhere else. [localizationsDelegates] are the feature's own. The
/// flow is always wrapped in `Localizations.override`: it adds the core strings
/// and Flutter's own delegates after them, only for the types the host does
/// not provide.
/// A failing [flowInitializer] shows an error view with Retry and reports the
/// error to [Monitoring] when the root has one.
/// [observers] watch the flow's own navigator (its pages), for example
/// `mc_analytics`' `AnalyticsFlowObserver`, which tracks the pages as screens
/// (T-0056). They are read once, when the flow is created.
class FeatureFlow<T> extends StatefulWidget {
  const FeatureFlow({
    required this.state,
    required this.onGeneratePages,
    this.flowInitializer,
    this.provide,
    this.localizationsDelegates = const [],
    this.rootImports = const <RootImport<Object>>[],
    this.onComplete,
    this.observers = const [],
    super.key,
  });

  /// The initial flow state.
  final T state;

  /// The first page is the flow's root; later pages are pushed on top.
  final OnGenerateFlowPages<T> onGeneratePages;

  final McDIInitializer? flowInitializer;

  /// Registers instances in the flow's container, before [flowInitializer].
  final void Function(GetIt scope)? provide;

  /// The feature's localisation delegates, installed for the flow's pages.
  /// Empty: the flow still adds the core and Flutter delegates the host lacks,
  /// and otherwise sees `Localizations` as the host set it.
  final List<LocalizationsDelegate<Object?>> localizationsDelegates;

  final List<RootImport<Object>> rootImports;

  /// Called once with the result passed to `FeatureFlowController.complete`.
  final ValueChanged<Object?>? onComplete;

  /// Observers of the flow's own navigator, after the flow's internal one.
  /// Read once, when the flow is created (like [provide]): a rebuild with
  /// other observers keeps the first ones.
  final List<NavigatorObserver> observers;

  @override
  State<FeatureFlow<T>> createState() => _FeatureFlowState<T>();
}

class _FeatureFlowState<T> extends State<FeatureFlow<T>> {
  late final FeatureFlowController<T> _controller;
  late final FlowController<T> _flowController;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  late Future<ChildDIContainer> _container;
  final Map<int, T> _snapshots = {};
  final NavigatorObserver _navigatorObserver = NavigatorObserver();
  late final List<NavigatorObserver> _observers = [
    _navigatorObserver,
    ...widget.observers,
  ];
  bool _forwarding = false;
  Object? _configError;
  StackTrace? _configStack;

  @override
  void initState() {
    super.initState();
    _controller = FeatureFlowController<T>(widget.state);
    _flowController = FlowController<T>(widget.state);
    _snapshots[_names(widget.state).length] = widget.state;
    // Controller -> pages.
    _subscriptions
      ..add(_controller.states.listen(_onControllerState))
      ..add(
        _controller.completions.listen(
          (result) => widget.onComplete?.call(result),
        ),
      );
    // Pages -> controller: a back gesture pops a page and changes the state.
    _flowController.addListener(_onFlowChanged);
    _container = _open();
  }

  /// The controller's state is authoritative. flow_builder records a history
  /// entry per update and a back gesture restores the previous entry, so only
  /// an update that changes the page stack may reach it; in-place updates
  /// reach the pages through [_LivePage].
  ///
  /// [_snapshots] holds, per page depth, the latest state seen while the stack
  /// had that depth. A pop to depth n restores the snapshot of depth n: what
  /// changed in a pushed page is dropped, what changed in the page below
  /// (while it was on top) is kept.
  void _onControllerState(T next) {
    final depth = _names(next).length;
    _snapshots
      ..removeWhere((d, _) => d > depth)
      ..[depth] = next;
    if (!listEquals(_names(_flowController.state), _names(next))) {
      _forwarding = true;
      try {
        _flowController.update((_) => next);
      } finally {
        _forwarding = false;
      }
    }
  }

  List<String> _names(T state) => [
    for (final page in widget.onGeneratePages(state)) page.name,
  ];

  /// Called for changes flow_builder makes itself: a back gesture or a pop.
  void _onFlowChanged() {
    if (_forwarding) {
      return;
    }
    final depth = _names(_controller.state).length - 1;
    final restored = _snapshots[depth] ?? _flowController.state;
    _snapshots.removeWhere((d, _) => d > depth);
    _controller.restore(restored);
  }

  Future<ChildDIContainer> _open() async {
    try {
      if (widget.rootImports.isNotEmpty) {
        // A missing root import is a wiring bug, not a runtime failure: probe
        // it first so it surfaces as a configuration error, not a Retry view.
        try {
          final probe = await createChildContainer(
            rootImports: widget.rootImports,
          );
          await probe.dispose();
        } on Object catch (error, stack) {
          _configError = error;
          _configStack = stack;
          rethrow;
        }
      }
      return await createChildContainer(
        rootImports: widget.rootImports,
        initializers: [
          McDIInitializer(
            (getIt, _) =>
                getIt.registerSingleton<FeatureFlowController<T>>(_controller),
          ),
          if (widget.provide case final provide?)
            McDIInitializer((getIt, _) => provide(getIt)),
          ?widget.flowInitializer,
        ],
      );
    } on Object catch (error, stack) {
      if (_configError == null) {
        _report(error, stack);
      }
      rethrow;
    }
  }

  void _report(Object error, StackTrace stack) {
    if (diContainer.isRegistered<Monitoring>()) {
      unawaited(diContainer<Monitoring>().recordError(error, stack));
    }
  }

  void _retry() => setState(() {
    _configError = null;
    _container = _open();
  });

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _flowController
      ..removeListener(_onFlowChanged)
      ..dispose();
    unawaited(_controller.dispose());
    unawaited(
      _container.then<void>((c) => c.dispose(), onError: (Object _) {}),
    );
    super.dispose();
  }

  List<Page<dynamic>> _pages(T state, List<Page<dynamic>> _) {
    final pages = widget.onGeneratePages(state);
    assert(
      {for (final page in pages) page.name}.length == pages.length,
      'FeatureFlow page names must be unique within one state, got '
      '${[for (final page in pages) page.name]}.',
    );
    return [
      for (final page in pages)
        MaterialPage<dynamic>(
          key: ValueKey<String>(page.name),
          name: page.name,
          arguments: page.arguments,
          child: _LivePage<T>(
            controller: _controller,
            name: page.name,
            generate: (s) => widget.onGeneratePages(s),
            initial: page.child,
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Always wrapped, so the tree keeps one shape whatever the delegates are.
    // `Localizations.override` puts the flow's delegates ahead of the host's
    // own, so the core and Flutter delegates are added only for the types the
    // host does not provide: a host override of, say, `MaterialLocalizations`
    // must survive inside the flow.
    final missing = [
      for (final delegate in mcLocalizationsDelegates)
        if (Localizations.of<Object>(context, delegate.type) == null) delegate,
    ];
    return Localizations.override(
      context: context,
      delegates: [...widget.localizationsDelegates, ...missing],
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FutureBuilder<ChildDIContainer>(
        future: _container,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final configError = _configError;
            if (configError != null) {
              Error.throwWithStackTrace(
                configError,
                _configStack ?? StackTrace.current,
              );
            }
            return McErrorView(message: _loadFailedMessage, onRetry: _retry);
          }
          final container = snapshot.data;
          if (container == null) {
            return const McLoading();
          }
          return _FlowScopeHost(
            container: container,
            controller: _controller,
            flowNavigatorObserver: _navigatorObserver,
            child: FlowBuilder<T>(
              controller: _flowController,
              onGeneratePages: _pages,
              observers: _observers,
            ),
          );
        },
      ),
    );
  }
}

/// Publishes the [FlowScope]. It depends on the flow's own outer route, so a
/// change of that route (a route below the flow, or `isCurrent` flipping when a
/// dialog opens above) rebuilds only this widget and republishes the scope. The
/// [child] is built by the caller and is the same instance, so the flow's
/// navigator and pages are not rebuilt.
class _FlowScopeHost extends StatelessWidget {
  const _FlowScopeHost({
    required this.container,
    required this.controller,
    required this.flowNavigatorObserver,
    required this.child,
  });

  final ChildDIContainer container;
  final FeatureFlowController<Object?> controller;
  final NavigatorObserver flowNavigatorObserver;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    return FlowScope(
      container: container,
      controller: controller,
      outerNavigator: Navigator.maybeOf(context),
      outerCanPop: route != null && !route.isFirst,
      outerRoute: route,
      outerIsCurrent: route?.isCurrent ?? true,
      flowNavigatorObserver: flowNavigatorObserver,
      child: child,
    );
  }
}

/// Rebuilds one page's content from the controller's current state, so an
/// in-place state change shows without touching the page stack.
class _LivePage<T> extends StatelessWidget {
  const _LivePage({
    required this.controller,
    required this.name,
    required this.generate,
    required this.initial,
  });

  final FeatureFlowController<T> controller;
  final String name;
  final OnGenerateFlowPages<T> generate;
  final Widget initial;

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: controller.states,
    initialData: controller.state,
    builder: (context, snapshot) {
      for (final page in generate(snapshot.data as T)) {
        if (page.name == name) {
          return page.child;
        }
      }
      // The page left the stack in this update; it is about to be removed.
      return initial;
    },
  );
}
