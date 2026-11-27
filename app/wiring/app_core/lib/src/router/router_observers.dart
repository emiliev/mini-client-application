import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_di/mc_di.dart';

/// The navigator observers every app router carries (`GoRouter(observers:)`):
/// screen tracking (T-0053). `Analytics` is looked up in the root container
/// when the first screen shows (`McApp` builds the router after boot, so it is
/// registered by then; a router built with no container, as a unit test does,
/// is fine until a page shows).
///
/// Screens are the routes' `name`s, so every route that is a screen must have
/// one (a snake_case name, as the typed routes' `name:`); a route without a
/// name is not tracked.
List<NavigatorObserver> appRouterObservers() => [
  AnalyticsRouteObserver.lazy(() => diContainer<Analytics>()),
];
