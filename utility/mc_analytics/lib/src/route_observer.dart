import 'package:flutter/widgets.dart';
import 'package:mc_analytics/src/analytics.dart';
import 'package:mc_analytics/src/event.dart';

/// Calls `Analytics.screen` with the name of each page route that becomes the
/// top route, whether by push, pop, replace or a `go` that rebuilds the stack.
///
/// - A route without a name, or whose name is not a valid screen name (a
///   go_router page falls back to its path, `/search`), is not tracked.
/// - Popups (dialogs, sheets, menus) are ignored: they are not `PageRoute`s.
/// - The same route becoming the top again with no other page in between (a
///   dialog closed over it) is not tracked twice.
///
/// Add it to `GoRouter(observers: [...])`. A nested flow's own navigator has
/// no observer here, so the pages inside a flow are not tracked.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final Analytics _analytics;
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
    _analytics.screen(name);
  }
}
