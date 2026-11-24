import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The publishing group (comics, series, creators)'s routes. Empty until its features exist.
const List<RouteBase> publishingRoutes = <RouteBase>[];

/// Registers the publishing group's navigator implementations. None yet.
class PublishingWiringDIInitializer extends McDIInitializer {
  const PublishingWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
