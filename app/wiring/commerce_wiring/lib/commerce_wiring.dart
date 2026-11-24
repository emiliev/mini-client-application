import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The commerce group (store, checkout)'s routes. Empty until its features exist.
const List<RouteBase> commerceRoutes = <RouteBase>[];

/// Registers the commerce group's navigator implementations. None yet.
class CommerceWiringDIInitializer extends McDIInitializer {
  const CommerceWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
