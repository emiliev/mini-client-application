import 'dart:async';

import 'package:comics_details/comics_details.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:publishing_wiring/src/di/di_initializer.dart';
import 'package:publishing_wiring/src/routes/route_targets.dart';
import 'package:publishing_wiring/src/routes/route_targets_impl.dart';

/// The publishing group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand,
/// R15). Needs `RouterDIInitializer`, the session and api auth before it in
/// the root list; a navigator reaches the router only when first used.
class PublishingWiringDIInitializer extends McDIInitializer {
  const PublishingWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const PublishingNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<PublishingRouteTargets>(
      () => PublishingRouteTargetsImpl(
        comicsDetails: getIt<ComicsDetailsNavigator>(),
      ),
    );
  }
}
