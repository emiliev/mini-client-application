// Typed routes (go_router_builder writes `app_routes.g.dart`). Placeholders
// until the wirings carry feature routes (T-0021).
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_config/mc_config.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_session/mc_session.dart';

import 'package:mini_client/src/pages/placeholder_pages.dart';

part 'app_routes.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/',
  // Route names are the screen names analytics tracks (T-0053).
  name: 'home',
  routes: [
    TypedGoRoute<PlaceholderRoute>(
      path: 'placeholder/:id',
      name: 'placeholder_detail',
    ),
  ],
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    McRouteProbe.record(context, 'home');
    return HomePlaceholderPage(
      env: diContainer<AppConfig>().env,
      onOpenPlaceholder: (id) => PlaceholderRoute(id: id).go(context),
      // A push, so Back returns home (the list is not a child of home).
      onOpenCharacters: () => unawaited(context.push(AppLocations.characters)),
      onOpenSearch: () => unawaited(context.push(AppLocations.search())),
      onOpenStore: () => unawaited(context.push(AppLocations.store)),
      onOpenTrivia: () => unawaited(context.push(AppLocations.trivia)),
      onOpenSettings: () => unawaited(context.push(AppLocations.settings)),
      // Flows that end with a result (plan 01 §4.3): push and await.
      onNewReadingList: () => AppFlows.createReadingList(GoRouter.of(context)),
      onEditReadingList: (id) =>
          AppFlows.editReadingList(GoRouter.of(context), id),
      // The session entry (T-0066): the sign-in screen is a result route.
      session: diContainer<SessionReader>(),
      onSignIn: () => AppFlows.signIn(GoRouter.of(context)),
      onSignOut: () => diContainer<AuthApi>().signOut(),
      dataChanges: diContainer<EventBus>().on<DataChanged>(),
    );
  }
}

/// Nested under home, so a deep link builds the back stack home → detail.
class PlaceholderRoute extends GoRouteData with $PlaceholderRoute {
  const PlaceholderRoute({required this.id});

  final int id;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    McRouteProbe.record(context, 'placeholder');
    return PlaceholderDetailPage(id: id);
  }
}
