import 'dart:async';

import 'package:commerce_wiring/src/di/di_initializer.dart';
import 'package:commerce_wiring/src/routes/route_targets.dart';
import 'package:commerce_wiring/src/routes/route_targets_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:store_home/store_home.dart';

/// The commerce group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand,
/// R15). Needs `RouterDIInitializer`, the session and api auth before it in
/// the root list; a navigator reaches the router only when first used.
class CommerceWiringDIInitializer extends McDIInitializer {
  const CommerceWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const CommerceNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<CommerceRouteTargets>(
      () => CommerceRouteTargetsImpl(
        storeHome: getIt<StoreHomeNavigator>(),
        clock: commerceClock(getIt),
      ),
    );
  }
}

/// The time the store's deals count down against: the backend's. While the
/// app runs on the mocked backend (it always does in v1, ADR-0005) that is
/// its fixed clock (`2026-01-01T00:00Z`), whose deals end 1 to 8 days later;
/// a real backend would mean the device's time.
DateTime Function() commerceClock(GetIt getIt) {
  if (!getIt.isRegistered<MockBackend>()) {
    return DateTime.now;
  }
  final backend = getIt<MockBackend>();
  return () => backend.clock;
}
