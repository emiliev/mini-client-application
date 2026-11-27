import 'package:flutter/widgets.dart';
import 'package:mc_analytics/src/analytics.dart';
import 'package:mc_analytics/src/event.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

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
/// Add it to `GoRouter(observers: [...])`. The pages inside a feature flow
/// are tracked by an [AnalyticsFlowObserver] on the flow's own navigator; a
/// route whose flow has moved to another page is tracked under that page's
/// name when it becomes the top again (T-0056).
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
    // A flow inside the route says which of its pages is showing.
    final flowPage = _flowScreens[topRoute];
    if (flowPage != null) {
      _report(topRoute, flowPage);
      return;
    }
    final name = topRoute.settings.name;
    if (name == null || !AnalyticsRules.isValidName(name)) {
      return;
    }
    final declared = screenNames;
    if (declared != null && !declared().contains(name)) {
      return;
    }
    _report(topRoute, name);
  }

  void _report(Route<dynamic> route, String name) {
    final analytics = _resolve();
    if (analytics == null) {
      return;
    }
    _reported[route] = name;
    analytics.screen(name);
  }
}

/// Per route of the app's navigator: the page its feature flow shows now
/// (set by [AnalyticsFlowObserver]), and the screen [AnalyticsRouteObserver]
/// last tracked for it. Keyed by the route object, so a route that is gone
/// is forgotten with it.
final Expando<String> _flowScreens = Expando('analytics flow screens');
final Expando<String> _reported = Expando('analytics reported screens');

/// Tracks the pages inside a feature flow (P-103, T-0056): put it on the
/// flow's own navigator (`FeatureFlow(observers: [...])`). A flow's pages are
/// `McFlowPage`s whose names are their screen names (`store_category`).
///
/// - **The flow's first page is the route's screen.** The route that hosts
///   the flow is tracked by the app's [AnalyticsRouteObserver] under its own
///   name, so the flow's first page is not tracked again when it has the same
///   name. Name a flow's first page as its route (`store_home` for the route
///   `store_home`). Outside an observed route (a feature test) the first page
///   is tracked.
/// - **A page pushed or popped inside the flow** is tracked when it becomes
///   the flow's top page, while the flow's route is the app's current route:
///   store → category → back is `store_home`, `store_category`, `store_home`.
/// - **Coming back to the route** (Back from another feature's screen) tracks
///   the page the flow shows, not the route's name: the route observer asks
///   this observer's record of the route.
/// - Popups are ignored, a page becoming the top again with no other page in
///   between is not tracked twice, and a name that is not a valid screen name
///   is not tracked. If [analytics] gives null, nothing is tracked.
///
/// [tracker] is called with the flow navigator's context, which is inside the
/// flow: `(context) => context.di<AnalyticsTracker>()` resolves the pure-Dart
/// port (`Analytics` itself) through the flow's root imports.
class AnalyticsFlowObserver extends NavigatorObserver {
  AnalyticsFlowObserver(this.tracker);

  final AnalyticsTracker? Function(BuildContext navigatorContext) tracker;
  Route<dynamic>? _last;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (topRoute is! PageRoute<dynamic> || identical(topRoute, _last)) {
      return;
    }
    _last = topRoute;
    final name = topRoute.settings.name;
    final context = navigator?.context;
    if (name == null || !AnalyticsRules.isValidName(name) || context == null) {
      return;
    }
    final host = ModalRoute.of(context);
    if (host != null) {
      _flowScreens[host] = name;
      // The first page of the flow: the route was tracked under this name.
      if (previousTopRoute == null && _reported[host] == name) {
        return;
      }
      // Hidden under another screen: tracked when the route comes back.
      if (!host.isCurrent) {
        return;
      }
      _reported[host] = name;
    }
    tracker(context)?.trackScreen(name);
  }
}
