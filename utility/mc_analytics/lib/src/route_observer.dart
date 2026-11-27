import 'package:flutter/widgets.dart';
import 'package:mc_analytics/src/analytics.dart';
import 'package:mc_analytics/src/event.dart';

/// Calls `Analytics.screen` with the name of each page route that becomes the
/// top route, whether by push, pop, replace or a `go` that rebuilds the stack.
///
/// - A route without a name, or whose name is not a valid screen name (a
///   go_router page falls back to its path, `/search`), is not tracked. With
///   `screenNames` (the router's declared `GoRoute.name`s) a relative path
///   such as `settings`, which is a valid name too, is not tracked either.
/// - Popups (dialogs, sheets, menus) are ignored: they are not `PageRoute`s.
/// - The same route becoming the top again with no other page in between (a
///   dialog closed over it) is not tracked twice.
///
/// Add it to `GoRouter(observers: [...])`. A nested flow's own navigator has
/// no observer here, so the pages inside a flow are not tracked.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(Analytics analytics, {this.screenNames})
    : _resolve = (() => analytics);

  /// Looks [analytics] up when the first screen is tracked, not when the
  /// observer is made: a router can be built before its container is ready,
  /// and a router that never shows a page never needs it. When it returns
  /// null (no container, or no `Analytics` in it) navigation goes on and
  /// nothing is tracked: tracking never breaks navigation.
  AnalyticsRouteObserver.lazy(
    Analytics? Function() analytics, {
    this.screenNames,
  }) : _resolve = analytics;

  /// The names the router declares for its screens (go_router's
  /// `GoRoute.name`s). When given, only a route whose name is in this set is a
  /// screen. go_router names an unnamed page by its **path**, and a nested
  /// relative path such as `settings` looks like a valid screen name, so the
  /// set is what tells a declared name from a path.
  final Set<String> Function()? screenNames;

  final Analytics? Function() _resolve;
  Route<dynamic>? _last;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute is! PageRoute<dynamic> || identical(topRoute, _last)) {
      return;
    }
    // Set before the name check: an unnamed page on top still counts as a
    // change, so the named page below is tracked again when it comes back.
    _last = topRoute;
    final name = topRoute.settings.name;
    if (name == null || !AnalyticsRules.isValidName(name)) {
      return;
    }
    final declared = screenNames;
    if (declared != null && !declared().contains(name)) {
      return;
    }
    _resolve()?.screen(name);
  }
}
