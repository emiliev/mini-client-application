import 'package:app_core/app_core.dart';
import 'package:go_router/go_router.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// The sandbox's router: the universe group's routes, opening on the
/// characters list; any other route shows [SandboxStubPage].
GoRouter buildSandboxRouter({required String initialLocation}) => GoRouter(
  initialLocation: initialLocation,
  overridePlatformDefaultLocation: true,
  routes: universeRoutes,
  redirect: (context, state) =>
      state.uri.path == AppLocations.home ? AppLocations.characters : null,
  errorBuilder: (context, state) =>
      SandboxStubPage(location: state.uri.toString()),
);
