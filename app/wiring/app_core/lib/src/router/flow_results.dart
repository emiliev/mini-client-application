import 'dart:async';

import 'package:app_core/src/locations/app_locations.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Flow results (plan 01 §4.3), the app layer's half. First used by the
/// reading-list editor (T-0048); every FW feature's wiring copies it.
///
/// 1. **The feature** ends its flow with a result:
///    `FeatureFlowController.complete(result)` in a bloc, and the flow widget
///    takes `onComplete: ValueChanged<R?>` (null: it ended without one). The
///    result type is the feature's own (`ReadingListId`), exported by its
///    barrel.
/// 2. **The wiring's route** builds the flow inside a [FlowResultRoute] and
///    passes its `complete` as `onComplete`, mapping the feature's type to
///    the app-level one (features never share types; `ReadingListId` becomes
///    its `String`). `complete` pops that route with the result.
/// 3. **The caller** pushes the route's location and awaits the push:
///    `GoRouter.push<T>` completes with the popped result, or with null when
///    the user left by Back. Callers use the typed entries in [AppFlows], so
///    the location and the result type are named once, here. A feature
///    that needs another feature's result asks through its own navigator;
///    the navigator implementation (in its wiring) awaits the [AppFlows]
///    entry and maps the result into its feature's type (`src/mappers/`).
///
/// **A result future always completes.** go_router never completes the
/// future of a `push` that a `go` replaced, so a caller awaiting
/// [GoRouter.push] alone would wait forever. [AppFlows] therefore pushes with
/// a [FlowCall] as the `extra`; the route (given `extra: state.extra`) ends it
/// with the result, or with null when it is disposed without one, whether it
/// was popped, replaced or removed by a `go`.
///
/// A route with nothing below it (a deep link opened it) has no caller to
/// answer: completing it goes home instead of popping the last page. A result
/// that arrives while something covers the route (a dialog, a sheet) is kept
/// and handed over as soon as the route is on top again: it is never dropped,
/// and what is above is never popped for it.
class FlowResultRoute<T> extends StatefulWidget {
  const FlowResultRoute({required this.builder, this.extra, super.key});

  /// The route's `state.extra`: a [FlowCall] when [AppFlows] pushed it.
  final Object? extra;

  /// Builds the flow; pass `complete` as its `onComplete`.
  final Widget Function(ValueChanged<T?> complete) builder;

  @override
  State<FlowResultRoute<T>> createState() => _FlowResultRouteState<T>();
}

class _FlowResultRouteState<T> extends State<FlowResultRoute<T>> {
  /// The result waiting for the route to be on top; set at most once.
  ({T? value})? _pending;
  bool _done = false;

  FlowCall<T>? get _call {
    final extra = widget.extra;
    return extra is FlowCall<T> ? extra : null;
  }

  /// The flow's `onComplete`. Later calls are ignored (a flow completes once).
  void _complete(T? result) {
    if (_done || _pending != null || !mounted) {
      return;
    }
    _pending = (value: result);
    _deliver();
  }

  /// Hands [_pending] over if the route is on top; otherwise waits for
  /// [didChangeDependencies], which runs when the route's `isCurrent`
  /// changes (this state depends on its `ModalRoute`).
  void _deliver() {
    final pending = _pending;
    final route = ModalRoute.of(context);
    if (pending == null || route == null || !route.isCurrent) {
      return;
    }
    _pending = null;
    _done = true;
    if (route.isFirst) {
      GoRouter.of(context).go(AppLocations.home);
    } else {
      Navigator.of(context).pop<T>(pending.value);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pending != null) {
      // Navigation may not change during a build: deliver after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _deliver();
        }
      });
    }
  }

  @override
  void dispose() {
    // Left without a result (Back, a `go` that replaced the route, ...).
    _call?.complete(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The dependency that brings [didChangeDependencies] when the route
    // becomes current again.
    ModalRoute.of(context);
    return widget.builder(_complete);
  }
}

/// One caller's wait for a result route, sent as the push's `extra`.
/// Completes once: with the flow's result, or with null when the route went
/// away without one. Later calls are ignored.
final class FlowCall<T> {
  final Completer<T?> _completer = Completer<T?>();

  /// Completes with the result of the route.
  Future<T?> get result => _completer.future;

  /// Completes the wait; ignored once completed.
  void complete(T? value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }
}

/// The flows that end with a result, as typed entries: push the route and
/// await what it ends with (plan 01 §4.3). One entry per result route; the
/// wiring's test checks each against its route.
abstract final class AppFlows {
  /// Opens the reading-list editor on a new list (library_wiring). Completes
  /// with the new list's id, or null when the user left without saving
  /// (Back, a declined sign-in).
  static Future<String?> createReadingList(GoRouter router) =>
      _open(router, AppLocations.newReadingList);

  /// Opens the reading-list editor on list [id]. Completes with [id] once
  /// saved (also when nothing changed), or null when the user left without
  /// saving.
  static Future<String?> editReadingList(GoRouter router, String id) =>
      _open(router, AppLocations.editReadingList(id));

  /// Pushes [location] and waits for the route's [FlowCall], which always
  /// completes (see [FlowResultRoute]).
  static Future<String?> _open(GoRouter router, String location) {
    final call = FlowCall<String>();
    unawaited(router.push<String>(location, extra: call).then(call.complete));
    return call.result;
  }
}
