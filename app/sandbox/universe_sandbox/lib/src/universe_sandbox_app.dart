import 'package:app_core/app_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_sandbox/src/universe_sandbox_router.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// `main()`'s link holder: the sandbox's own scheme, so a cold-start link and a
/// link during boot are judged alike.
PendingLinks installSandboxLinks(WidgetsBinding binding) =>
    PendingLinks.install(binding, scheme: sandboxLinkScheme);

/// The asset Bazel bundles from `//tool/bazel/config:app_config` (R13).
const String appConfigAsset = 'assets/app_config.json';

/// The sandbox's root list: the shared utilities and only the universe wiring.
List<McDIInitializer> sandboxRootInitializers({RouterRef? routerRef}) =>
    rootInitializers(
      config: () => rootBundle.loadString(appConfigAsset),
      storageDirectory: appStorageDirectory(),
      mockDomains: appMockDomains,
      routerRef: routerRef,
      wirings: const [UniverseWiringDIInitializer()],
    );

/// `McApp` over the universe wiring alone (plan 01 §6.3).
class UniverseSandboxApp extends StatefulWidget {
  const UniverseSandboxApp({
    required this.links,
    this.initializers,
    super.key,
  });

  /// Made with `PendingLinks.install(binding, scheme: sandboxLinkScheme)`.
  final PendingLinks links;

  /// Overrides [sandboxRootInitializers] (tests); gets the app's [RouterRef].
  final List<McDIInitializer> Function(RouterRef routerRef)? initializers;

  @override
  State<UniverseSandboxApp> createState() => _UniverseSandboxAppState();
}

class _UniverseSandboxAppState extends State<UniverseSandboxApp> {
  final RouterRef _routerRef = RouterRef();

  @override
  Widget build(BuildContext context) => McApp(
    title: 'Universe Sandbox',
    boot: () => initializeDIContainer(
      widget.initializers?.call(_routerRef) ??
          sandboxRootInitializers(routerRef: _routerRef),
    ),
    router: (initialLocation) =>
        buildSandboxRouter(initialLocation: initialLocation),
    links: widget.links,
    routerRef: _routerRef,
    appBuilder: mediaScopeBuilder,
  );
}
