import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The chronicle group (events, stories, trivia)'s routes. Empty until its features exist.
const List<RouteBase> chronicleRoutes = <RouteBase>[];

/// Registers the chronicle group's navigator implementations. None yet.
class ChronicleWiringDIInitializer extends McDIInitializer {
  const ChronicleWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
