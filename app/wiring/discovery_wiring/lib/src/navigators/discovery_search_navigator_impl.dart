import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:discovery_search/discovery_search.dart';
import 'package:injectable/injectable.dart';

/// discovery_search's way out of the feature: its intents become routes.
/// It holds the [RouterRef], not a router, and asks for the live router at
/// each call (T-0033), so after the app's router is replaced it still pushes
/// to the one on screen.
///
/// Both targets are other groups' (universe, publishing), so they go through
/// `AppLocations` (plan 01 §4.2). Each is a push, so Back returns to the
/// results.
@LazySingleton(as: DiscoverySearchNavigator)
class DiscoverySearchNavigatorImpl implements DiscoverySearchNavigator {
  DiscoverySearchNavigatorImpl(this._routerRef);

  final RouterRef _routerRef;

  @override
  void openCharacter(CharacterId id) {
    unawaited(_routerRef.router.push(AppLocations.character(id.value)));
  }

  @override
  void openComic(ComicId id) {
    unawaited(_routerRef.router.push(AppLocations.comic(id.value)));
  }
}
