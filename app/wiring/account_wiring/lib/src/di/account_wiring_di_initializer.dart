import 'dart:async';

import 'package:account_wiring/src/di/di_initializer.dart';
import 'package:account_wiring/src/routes/route_targets.dart';
import 'package:account_wiring/src/routes/route_targets_impl.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:settings_appearance/settings_appearance.dart';

/// The account group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand,
/// R15). Needs `RouterDIInitializer`, the session and api auth before it in
/// the root list; a navigator reaches the router only when first used.
class AccountWiringDIInitializer extends McDIInitializer {
  const AccountWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const AccountNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<AccountRouteTargets>(
      () => AccountRouteTargetsImpl(
        settingsAppearance: getIt<SettingsAppearanceNavigator>(),
      ),
    );
  }
}
