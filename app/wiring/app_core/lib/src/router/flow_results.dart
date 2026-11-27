import 'dart:async';
import 'dart:convert';

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
    // Remembered by the call too, so that a result held under an overlay is
    // not lost when the call ends some other way (P-096).
    _call?._hold(result);
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
    // Direct, so the result never depends on microtask order: dispose (which
    // completes with null) may come in the same synchronous span as the pop.
    _call?.complete(pending.value);
    if (route.isFirst) {
      GoRouter.of(context).go(AppLocations.home);
    } else {
      Navigator.of(context).pop<T>(pending.value);
    }
  }

  bool _checked = false;

  /// Debug only: a route [AppFlows] opened must have been given its
  /// [FlowCall]; without `extra: state.extra` its caller would wait forever.
  /// (Here, not in `initState`: it reads the route's state, an inherited
  /// widget.)
  bool _debugCheckCall() {
    if (_checked) {
      return true;
    }
    _checked = true;
    if (GoRouter.maybeOf(context) == null) {
      return true;
    }
    final state = GoRouterState.of(context);
    // The call travels as go_router's `extra`: a route pushed with one but
    // built without it forgot `extra: state.extra`. A route a later `go`
    // built (a guard's `from=`) has no call in its state, so it is never
    // mistaken for that.
    if (_call == null && state.extra is FlowCall) {
      throw FlutterError(
        'FlowResultRoute at ${state.uri} was opened through AppFlows but '
        'built without its FlowCall, so the caller would wait forever.\n'
        'Pass `extra: state.extra` to FlowResultRoute in the route.',
      );
    }
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(_debugCheckCall());
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
    // Left without a result (Back, a `go` that replaced the route, ...), or
    // replaced while a result waited under an overlay (P-096): that one is
    // delivered, not lost.
    _call?.abandon();
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
  FlowCall();

  final Completer<T?> _completer = Completer<T?>();

  /// Completes with the result of the route.
  Future<T?> get result => _completer.future;

  /// The result the route has but could not hand over yet (an overlay).
  ({T? value})? _held;

  void _hold(T? value) => _held ??= (value: value);

  /// The route or its page went away without handing a result over: the
  /// caller gets the result the route held (P-096), else null.
  void abandon() => complete(_held?.value);

  /// Whether the wait has ended.
  bool get isCompleted => _completer.isCompleted;

  /// Completes the wait; ignored once completed.
  void complete(T? value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }
}

/// go_router's `extraCodec` for the app: what of a route's `extra` survives a
/// save of the route state (the iOS route report).
///
/// - A [FlowCall] is **transient** (a live future can't be saved): it encodes
///   as null and decodes as no call.
/// - A JSON-safe value (null, bool, finite num, String, and Lists and Maps
///   with String keys of those) passes through unchanged.
/// - **Anything else is dropped** (saved as null, so decoded as null) with a
///   debug-only warning naming its type, once per type. It never throws: with
///   no codec go_router would throw `JsonUnsupportedObjectError` for it in
///   the engine's route report.
///
/// So a route that reads `state.extra` treats null as "no argument".
final class FlowExtraCodec extends Codec<Object?, Object?> {
  const FlowExtraCodec();

  @override
  Converter<Object?, Object?> get encoder => const _FlowExtraConverter(true);

  @override
  Converter<Object?, Object?> get decoder => const _FlowExtraConverter(false);
}

/// Types the codec already warned about (debug only).
final Set<Type> _warnedExtraTypes = <Type>{};

/// Forgets which extra types were warned about, so a test sees the warning.
@visibleForTesting
void resetFlowExtraWarnings() => _warnedExtraTypes.clear();

class _FlowExtraConverter extends Converter<Object?, Object?> {
  const _FlowExtraConverter(this._encoding);

  final bool _encoding;

  @override
  Object? convert(Object? input) {
    if (input == null || input is FlowCall) {
      return null;
    }
    if (_isJsonSafe(input, 0)) {
      return input;
    }
    assert(() {
      if (_encoding && _warnedExtraTypes.add(input.runtimeType)) {
        debugPrint(
          'FlowExtraCodec: dropping a route extra of type '
          '${input.runtimeType} when the route state is saved. Only JSON-safe '
          'values (null, bool, num, String, List, Map<String, ...>) are kept; '
          'the route sees null after a restore.',
        );
      }
      return true;
    }());
    return null;
  }

  static bool _isJsonSafe(Object? value, int depth) {
    if (depth > 32) {
      return false;
    }
    return switch (value) {
      null || bool() || String() => true,
      final num n => n.isFinite,
      final List<Object?> list => list.every((e) => _isJsonSafe(e, depth + 1)),
      final Map<Object?, Object?> map => map.entries.every(
        (e) => e.key is String && _isJsonSafe(e.value, depth + 1),
      ),
      _ => false,
    };
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

  /// Pushes [location] and waits for a [FlowCall], which completes exactly
  /// once, whatever happens to the push (see [FlowResultRoute]):
  ///
  /// - the route ends with a result, or is disposed (it completes the call);
  /// - the push's own future completes (a pop; also of a page a redirect
  ///   showed instead of the route);
  /// - a `go` replaces the pushed page, even one a redirect sent elsewhere
  ///   (go_router never completes the push then): the router's stack is
  ///   watched for the page, and the call completes (with a result the route
  ///   still held, else null) once the page is gone. The check runs after the
  ///   next frame, so a route holding a result under an overlay is not cut
  ///   short.
  ///
  /// The page is found by its push future: a redirect drops the `extra`, but
  /// the match keeps the completer that the push returned.
  static Future<String?> _open(GoRouter router, String location) {
    final call = FlowCall<String>();
    final delegate = router.routerDelegate;
    late final Future<String?> push;
    var seen = false;
    void check() {
      if (call.isCompleted) {
        return;
      }
      if (_stackHolds(delegate.currentConfiguration, push)) {
        seen = true;
      } else if (seen) {
        call.abandon();
      }
    }

    void onChange() {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => check())
        ..scheduleFrame();
    }

    // Listening before the push: the router may apply it at once.
    delegate.addListener(onChange);
    unawaited(
      call.result.whenComplete(() => delegate.removeListener(onChange)),
    );
    push = router.routeInformationProvider.push<String>(
      location,
      base: delegate.currentConfiguration,
      extra: call,
    );
    unawaited(push.then(call.complete));
    onChange();
    return call.result;
  }

  /// Whether the page [push] returned the future of is in [list]'s stack.
  static bool _stackHolds(RouteMatchList list, Future<Object?> push) {
    bool within(List<RouteMatchBase> matches) {
      for (final match in matches) {
        if (match is ImperativeRouteMatch &&
            identical(match.completer.future, push)) {
          return true;
        }
        if (match is ShellRouteMatch && within(match.matches)) {
          return true;
        }
      }
      return false;
    }

    return within(list.matches);
  }
}
