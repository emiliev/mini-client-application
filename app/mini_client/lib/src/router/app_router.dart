import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mini_client/src/pages/placeholder_pages.dart';
import 'package:mini_client/src/router/app_routes.dart';
import 'package:mini_client/src/wirings.dart';

/// The app's router. `McApp` calls this once, when boot is ready, with the
/// held deep link (R29). The shell (`StatefulShellRoute`, 5 tabs) arrives
/// with the first features.
///
/// The sign-in guard (plan 01 §4.2, T-0066) reads [session], which is the
/// root's `SessionReader` unless a test passes its own.
GoRouter buildAppRouter({
  required String initialLocation,
  SessionReader? session,
}) {
  // The observer needs the router's declared names, and the router needs the
  // observer: it asks for the names when the first screen shows.
  late final GoRouter router;
  final guard = SignInGuard(session ?? diContainer<SessionReader>());
  router = _buildRouter(
    initialLocation,
    guard,
    appRouterObservers(
      screenNames: () => goRouteNames(router.configuration.routes),
    ),
  );
  guard.bind(router);
  return router;
}

GoRouter _buildRouter(
  String initialLocation,
  SignInGuard guard,
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
  // Every wiring's routes come from `mcgen wire`'s list (T-0074); the
  // catalogue lists the generated flows, in debug and profile builds only.
  routes: nestUnderHome($appRoutes, [
    ...wiringRoutes,
    notFoundRoute,
    if (!kReleaseMode) catalogueRoute,
  ]),
  // The sign-in guard (P1-16 AC4) re-evaluates on every sign-out (not on a
  // sign-in), so signing out on a protected screen redirects.
  refreshListenable: guard.refresh,
  redirect: (context, state) {
    McRouteProbe.recordRedirect(context, state.uri);
    // Only miniclient://app/… links are the app's (as PendingLinks.normalise).
    final uri = state.uri;
    if (LinkScheme.app.isForeign(uri)) {
      return AppLocations.home;
    }
    // Signed out on `/me/**`, `/library/**` or `/store/checkout`:
    // `/auth/sign-in?from=<where they were going>`.
    return guard.redirect(uri);
  },
  // Unknown paths and bad ids (a path or redirect error) land on the
  // not-found route, nested under home like every other (T-0054).
  onException: (context, state, router) =>
      router.go(notFoundLocation(_asked(state.uri))),
);

/// `/catalogue` (T-0074, P2-08): every generated flow, one tap away. Home has
/// no link to it; `buildAppRouter` leaves it out of release builds.
final GoRoute catalogueRoute = GoRoute(
  name: 'catalogue',
  path: AppLocations.catalogue,
  builder: (context, state) {
    McRouteProbe.record(context, 'catalogue');
    return const CataloguePage(entries: catalogueEntries);
  },
);

/// The not-found screen's route: unknown paths and bad ids go here with
/// `from` set to what was asked for, so it opens as `[home, not-found]`
/// whether the app is cold or running (T-0054, P-097).
final GoRoute notFoundRoute = GoRoute(
  name: 'not_found',
  path: _notFoundPath,
  builder: (context, state) =>
      NotFoundPage(location: state.uri.queryParameters['from'] ?? ''),
);

const _notFoundPath = '/not-found';

/// What a link asked for, without its scheme and host: a link in the running
/// app arrives as `miniclient://app/nope`, and the screen shows `/nope`.
String _asked(Uri uri) => Uri(
  path: uri.path,
  query: uri.hasQuery ? uri.query : null,
  fragment: uri.hasFragment ? uri.fragment : null,
).toString();

/// The location of the not-found screen for a failed [from].
String notFoundLocation(String from) =>
    Uri(path: _notFoundPath, queryParameters: {'from': from}).toString();
