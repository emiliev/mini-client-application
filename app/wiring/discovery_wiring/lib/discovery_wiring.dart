import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The discovery group (home, search)'s routes. Empty until its features exist.
const List<RouteBase> discoveryRoutes = <RouteBase>[];

/// Registers the discovery group's navigator implementations. None yet.
class DiscoveryWiringDIInitializer extends McDIInitializer {
  const DiscoveryWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
