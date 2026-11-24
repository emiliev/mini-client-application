import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

/// The library group (reading lists, collections)'s routes. Empty until its features exist.
const List<RouteBase> libraryRoutes = <RouteBase>[];

/// Registers the library group's navigator implementations. None yet.
class LibraryWiringDIInitializer extends McDIInitializer {
  const LibraryWiringDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {}
}
