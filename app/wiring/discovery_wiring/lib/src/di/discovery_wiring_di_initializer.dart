import 'dart:async';

import 'package:discovery_search/discovery_search.dart';
import 'package:discovery_wiring/src/di/di_initializer.dart';
import 'package:discovery_wiring/src/routes/route_targets.dart';
import 'package:discovery_wiring/src/routes/route_targets_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';

/// The discovery group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand,
/// R15). Needs `RouterDIInitializer` before it in the root list; a navigator
/// reaches the router only when first used.
class DiscoveryWiringDIInitializer extends McDIInitializer {
  const DiscoveryWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const DiscoveryNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<DiscoveryRouteTargets>(
      () => DiscoveryRouteTargetsImpl(
        discoverySearch: getIt<DiscoverySearchNavigator>(),
      ),
    );
  }
}
