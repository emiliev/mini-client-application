import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:library_wiring/src/routes/route_targets.dart';
import 'package:mc_di/mc_di.dart';

part 'reading_lists_routes.g.dart';

/// The library group's reading-list routes (generated `$appRoutes`).
List<RouteBase> get readingListsRoutes => $appRoutes;

/// `/me/lists/new`: the reading-list editor on a new list.
///
/// **A route that ends with a result** (plan 01 §4.3): the flow is built in
/// a [FlowResultRoute], whose `complete` is the flow's `onComplete`, so the
/// route pops itself with the new list's id. Push it with
/// `AppFlows.createReadingList` and await the id. A deep link
/// (`miniclient://app/me/lists/new`) opens it with nobody to answer; the app
/// shell nests it under home (T-0049), so completing pops back to home.
@TypedGoRoute<NewReadingListRoute>(
  path: '/me/lists/new',
  name: 'reading_list_new',
)
class NewReadingListRoute extends GoRouteData with $NewReadingListRoute {
  const NewReadingListRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      FlowResultRoute<String>(
        extra: state.extra,
        builder: (complete) => diContainer<LibraryRouteTargets>()
            .newReadingList(onComplete: complete),
      );
}

/// `/me/lists/:id/edit`: the reading-list editor on list [id]. Ends with the
/// list's id once saved (`AppFlows.editReadingList`), like
/// [NewReadingListRoute].
@TypedGoRoute<EditReadingListRoute>(
  path: '/me/lists/:id/edit',
  name: 'reading_list_edit',
)
class EditReadingListRoute extends GoRouteData with $EditReadingListRoute {
  const EditReadingListRoute({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      FlowResultRoute<String>(
        extra: state.extra,
        builder: (complete) => diContainer<LibraryRouteTargets>()
            .editReadingList(id, onComplete: complete),
      );
}
