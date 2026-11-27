import 'package:go_router/go_router.dart';

/// Nests entity routes under home (plan 01 §4.2), so a deep link builds the
/// back stack `[home, target]` and the first screen can go back (T-0049).
///
/// Each wiring owns its typed routes with their **absolute** paths
/// (`/comics/:id`), so `XRoute(...).location` and `AppLocations` never
/// change. go_router needs a child's path relative to its parent, so the app
/// shell re-roots them here: the generated route is copied with the leading
/// `/` removed, children kept. The URL that matches is the same.
///
/// A top-level route that is not re-rooted is a one-page stack when a link
/// opens it, so `buildAppRouter` passes every wiring's routes through
/// [nestUnderHome].
List<RouteBase> nestUnderHome(
  List<RouteBase> appRoutes,
  List<RouteBase> entityRoutes,
) {
  final homes = appRoutes.whereType<GoRoute>().where((r) => r.path == '/');
  if (homes.length != 1) {
    throw StateError('Exactly one home route (path "/") is required.');
  }
  final home = homes.single;
  return [
    for (final route in appRoutes)
      if (identical(route, home))
        _copy(
          home,
          path: home.path,
          routes: [...home.routes, ...entityRoutes.map(_relative)],
        )
      else
        route,
  ];
}

GoRoute _relative(RouteBase route) {
  if (route is! GoRoute || !route.path.startsWith('/')) {
    throw StateError(
      'Only absolute GoRoutes nest under home, got ${route.runtimeType} '
      '${route is GoRoute ? route.path : ''}.',
    );
  }
  return _copy(route, path: route.path.substring(1), routes: route.routes);
}

GoRoute _copy(
  GoRoute route, {
  required String path,
  required List<RouteBase> routes,
}) => GoRoute(
  path: path,
  name: route.name,
  builder: route.builder,
  pageBuilder: route.pageBuilder,
  parentNavigatorKey: route.parentNavigatorKey,
  redirect: route.redirect,
  metadata: route.metadata,
  onExit: route.onExit,
  caseSensitive: route.caseSensitive,
  routes: routes,
);
