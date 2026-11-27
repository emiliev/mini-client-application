import 'package:account_wiring/account_wiring.dart';
import 'package:app_core/app_core.dart';
import 'package:chronicle_wiring/chronicle_wiring.dart';
import 'package:commerce_wiring/commerce_wiring.dart';
import 'package:discovery_wiring/discovery_wiring.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:library_wiring/library_wiring.dart';
import 'package:mini_client/src/pages/placeholder_pages.dart';
import 'package:mini_client/src/router/app_routes.dart';
import 'package:publishing_wiring/publishing_wiring.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// The app's router. `McApp` calls this once, when boot is ready, with the
/// held deep link (R29). The shell (`StatefulShellRoute`, 5 tabs) arrives
/// with the first features.
GoRouter buildAppRouter({required String initialLocation}) {
  // The observer needs the router's declared names, and the router needs the
  // observer: it asks for the names when the first screen shows.
  late final GoRouter router;
  router = _buildRouter(
    initialLocation,
    appRouterObservers(
      screenNames: () => goRouteNames(router.configuration.routes),
    ),
  );
  return router;
}

GoRouter _buildRouter(
  String initialLocation,
  List<NavigatorObserver> observers,
) => GoRouter(
  initialLocation: initialLocation,
  // The link PendingLinks held wins over the platform's initial route.
  overridePlatformDefaultLocation: true,
  // A FlowCall (AppFlows' wait) is transient: not serialised, not warned on.
  extraCodec: const FlowExtraCodec(),
  // Screen tracking (T-0053): every route's `name` is its screen.
  observers: observers,
  // Every entity route nests under home (plan 01 §4.2, T-0049), so a link
  // opens `[home, target]` and the first screen can go back.
  routes: nestUnderHome($appRoutes, [
    ...discoveryRoutes,
    ...universeRoutes,
    ...publishingRoutes,
    ...chronicleRoutes,
    ...commerceRoutes,
    ...libraryRoutes,
    ...accountRoutes,
  ]),
  // The auth guard (P1-16 AC4) joins here with mc_api_auth.
  redirect: (context, state) {
    McRouteProbe.recordRedirect(context, state.uri);
    // Only miniclient://app/… links are the app's (as PendingLinks.normalise).
    final uri = state.uri;
    if (LinkScheme.app.isForeign(uri)) {
      return AppLocations.home;
    }
    return null;
  },
  errorBuilder: (context, state) =>
      NotFoundPage(location: state.uri.toString()),
);
