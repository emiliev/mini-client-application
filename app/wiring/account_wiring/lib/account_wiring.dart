import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The account group (profile, settings, auth)'s routes. Empty until its features exist.
const List<RouteBase> accountRoutes = <RouteBase>[];

/// Registers the account group's navigator implementations. None yet.
class AccountWiringDIInitializer extends McDIInitializer {
  const AccountWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
