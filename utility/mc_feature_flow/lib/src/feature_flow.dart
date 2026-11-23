import 'dart:async';

import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_feature_flow/src/flow_context.dart';
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
/// A failing [flowInitializer] shows an error view with Retry and reports the
/// error to [Monitoring] when the root has one.
class FeatureFlow<T> extends StatefulWidget {
  const FeatureFlow({
    required this.state,
    required this.onGeneratePages,
    this.flowInitializer,
    this.rootImports = const <RootImport<Object>>[],
    this.onComplete,
    super.key,
  });

  /// The initial flow state.
  final T state;

  /// The first page is the flow's root; later pages are pushed on top.
  final OnGenerateFlowPages<T> onGeneratePages;

  final McDIInitializer? flowInitializer;
  final List<RootImport<Object>> rootImports;

  /// Called once with the result passed to `FeatureFlowController.complete`.
  final ValueChanged<Object?>? onComplete;

  @override
  State<FeatureFlow<T>> createState() => _FeatureFlowState<T>();
}

class _FeatureFlowState<T> extends State<FeatureFlow<T>> {
  late final FeatureFlowController<T> _controller;
  late final FlowController<T> _flowController;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  late Future<ChildDIContainer> _container;
  Object? _configError;
  StackTrace? _configStack;

  @override
  void initState() {
    super.initState();
    _controller = FeatureFlowController<T>(widget.state);
    _flowController = FlowController<T>(widget.state);
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

  /// flow_builder records a history entry per update and a back gesture
  /// restores the previous entry, so only an update that changes the page
  /// stack may reach it. In-place updates stay in the controller and reach
  /// the pages through [_LivePage].
  void _onControllerState(T next) {
    if (!listEquals(_names(_flowController.state), _names(next))) {
      _flowController.update((_) => next);
    }
  }

  List<String> _names(T state) => [
    for (final page in widget.onGeneratePages(state)) page.name,
  ];

  void _onFlowChanged() => _controller.restore(_flowController.state);

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
          return FlowScope(
            container: container,
            child: FlowBuilder<T>(
              controller: _flowController,
              onGeneratePages: _pages,
            ),
          );
        },
      ),
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
