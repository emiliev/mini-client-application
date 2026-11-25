import 'package:app_core/app_core.dart';
import 'package:go_router/go_router.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// The sandbox's links: `miniclientuniverse://app/…` (its Info.plist scheme).
const LinkScheme sandboxLinkScheme = LinkScheme('miniclientuniverse', 'app');

/// The sandbox's router: the universe group's routes, opening on the
/// characters list; any other route shows [SandboxStubPage]. A link for
/// another scheme or host is not the sandbox's and opens the list, the same
/// as `PendingLinks` treats a cold-start link.
GoRouter buildSandboxRouter({
  required String initialLocation,
  LinkScheme scheme = sandboxLinkScheme,
}) => GoRouter(
  initialLocation: initialLocation,
  overridePlatformDefaultLocation: true,
  routes: universeRoutes,
  redirect: (context, state) {
    final uri = state.uri;
    if (scheme.isForeign(uri) || uri.path == AppLocations.home) {
      return AppLocations.characters;
    }
    return null;
  },
  errorBuilder: (context, state) =>
      SandboxStubPage(location: state.uri.toString()),
);
