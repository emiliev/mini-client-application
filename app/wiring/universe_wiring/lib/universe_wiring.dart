import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The universe group (characters, teams, locations)'s routes. Empty until its features exist.
const List<RouteBase> universeRoutes = <RouteBase>[];

/// Registers the universe group's navigator implementations. None yet.
class UniverseWiringDIInitializer extends McDIInitializer {
  const UniverseWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
