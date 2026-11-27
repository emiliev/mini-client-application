import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_di/mc_di.dart';

/// The navigator observers every app router carries (`GoRouter(observers:)`):
/// screen tracking (T-0053).
///
/// `Analytics` is looked up in the root container when a screen shows
/// (`McApp` builds the router after boot, so it is registered by then). If it
/// is not registered, nothing is tracked and navigation goes on: tracking never
/// breaks navigation (a router built in a unit test has no container).
///
/// [screenNames] gives the names the router declares (see [goRouteNames]); a
/// page go_router named by its path is then not a screen. Pass it lazily, as
/// the router does not exist yet when its observers are made.
///
/// Screens are the routes' `name`s, so every route that is a screen must have
/// one (a snake_case name, as the typed routes' `name:`).
List<NavigatorObserver> appRouterObservers({
  Set<String> Function()? screenNames,
}) => [
  AnalyticsRouteObserver.lazy(
    () =>
        diContainer.isRegistered<Analytics>() ? diContainer<Analytics>() : null,
    screenNames: screenNames,
  ),
];

/// Every `name` declared by [routes] and their children.
Set<String> goRouteNames(List<RouteBase> routes) => {
  for (final route in routes) ...[
    if (route is GoRoute && route.name != null) route.name!,
    ...goRouteNames(route.routes),
  ],
};
