import 'package:app_core/src/locations/app_locations.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Flow results (plan 01 §4.3), the app layer's half. First used by the
/// reading-list editor (T-0048); every FW feature's wiring copies it.
///
/// 1. **The feature** ends its flow with a result:
///    `FeatureFlowController.complete(result)` in a bloc, and the flow widget
///    takes `onComplete: ValueChanged<R?>` (null: it ended without one). The
///    result type is the feature's own (`ReadingListId`), exported by its
///    barrel.
/// 2. **The wiring's route** builds the flow inside a [FlowResultRoute] and
///    passes its `complete` as `onComplete`, mapping the feature's type to
///    the app-level one (features never share types; `ReadingListId` becomes
///    its `String`). `complete` pops that route with the result.
/// 3. **The caller** pushes the route's location and awaits the push:
///    `GoRouter.push<T>` completes with the popped result, or with null when
///    the user left by Back. Callers use the typed entries in [AppFlows], so
///    the location and the result type are named once, here. A feature
///    that needs another feature's result asks through its own navigator;
///    the navigator implementation (in its wiring) awaits the [AppFlows]
///    entry and maps the result into its feature's type (`src/mappers/`).
///
/// A route with nothing below it (a deep link opened it) has no caller to
/// answer: completing it goes home instead of popping the last page.
class FlowResultRoute<T> extends StatelessWidget {
  const FlowResultRoute({required this.builder, super.key});

  /// Builds the flow; pass `complete` as its `onComplete`.
  final Widget Function(ValueChanged<T?> complete) builder;

  @override
  Widget build(BuildContext context) =>
      builder((result) => completeRoute<T>(context, result));
}

/// Ends the route that [context] belongs to with [result] (see
/// [FlowResultRoute]):
/// - on top, with a route below it: pops it with [result], which completes
///   the caller's `push<T>`;
/// - on top and the only route (a deep link): goes home, as nobody awaits it;
/// - not on top (a dialog or sheet is above it): does nothing, so it never
///   pops what is above. A flow completes from a tap on its own page, so this
///   does not happen in practice; the route stays and its caller gets null
///   when it is left.
void completeRoute<T>(BuildContext context, T? result) {
  if (!context.mounted) {
    return;
  }
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) {
    return;
  }
  if (route.isFirst) {
    GoRouter.of(context).go(AppLocations.home);
    return;
  }
  Navigator.of(context).pop<T>(result);
}

/// The flows that end with a result, as typed entries: push the route and
/// await what it ends with (plan 01 §4.3). One entry per result route; the
/// wiring's test checks each against its route.
abstract final class AppFlows {
  /// Opens the reading-list editor on a new list (library_wiring). Completes
  /// with the new list's id, or null when the user left without saving
  /// (Back, a declined sign-in).
  static Future<String?> createReadingList(GoRouter router) =>
      router.push<String>(AppLocations.newReadingList);

  /// Opens the reading-list editor on list [id]. Completes with [id] once
  /// saved (also when nothing changed), or null when the user left without
  /// saving.
  static Future<String?> editReadingList(GoRouter router, String id) =>
      router.push<String>(AppLocations.editReadingList(id));
}
