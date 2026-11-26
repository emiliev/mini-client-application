import 'dart:async';

import 'package:characters_list/characters_list.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_wiring/src/di/di_initializer.dart';
import 'package:universe_wiring/src/routes/route_targets.dart';
import 'package:universe_wiring/src/routes/route_targets_impl.dart';

/// The universe group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand, R15).
/// Needs a `GoRouter` in the root container (`RouterDIInitializer`) by the
/// time a navigator is first used.
class UniverseWiringDIInitializer extends McDIInitializer {
  const UniverseWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const UniverseNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<UniverseRouteTargets>(
      () => UniverseRouteTargetsImpl(
        charactersList: getIt<CharactersListNavigator>(),
      ),
    );
  }
}
