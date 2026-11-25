import 'package:account_wiring/account_wiring.dart';
import 'package:app_core/app_core.dart';
import 'package:chronicle_wiring/chronicle_wiring.dart';
import 'package:commerce_wiring/commerce_wiring.dart';
import 'package:discovery_wiring/discovery_wiring.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:library_wiring/library_wiring.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mini_client/src/router/app_router.dart';
import 'package:publishing_wiring/publishing_wiring.dart';
import 'package:universe_wiring/universe_wiring.dart';

/// The asset Bazel bundles from `//tool/bazel/config:app_config` (R13).
const String appConfigAsset = 'assets/app_config.json';

/// Every wiring's DI initializer (navigator implementations), in group order.
const List<McDIInitializer> wiringInitializers = [
  DiscoveryWiringDIInitializer(),
  UniverseWiringDIInitializer(),
  PublishingWiringDIInitializer(),
  ChronicleWiringDIInitializer(),
  CommerceWiringDIInitializer(),
  LibraryWiringDIInitializer(),
  AccountWiringDIInitializer(),
];

/// The production root list: config from the bundled asset, storage in the
/// app's data container, and all 7 wirings.
List<McDIInitializer> appRootInitializers({RouterRef? routerRef}) =>
    rootInitializers(
      config: () => rootBundle.loadString(appConfigAsset),
      storageDirectory: appStorageDirectory(),
      mockDomains: appMockDomains,
      routerRef: routerRef,
      wirings: wiringInitializers,
    );

/// The Marvel app: [McApp] over the app router.
class MiniClientApp extends StatefulWidget {
  const MiniClientApp({
    required this.links,
    this.initializers,
    this.router,
    this.bootTimeout = defaultBootTimeout,
    this.probe,
    super.key,
  });

  final PendingLinks links;

  /// Overrides [appRootInitializers] (tests). Gets the app's [RouterRef], so
  /// a test boots with the same router wiring as production.
  final List<McDIInitializer> Function(RouterRef routerRef)? initializers;

  /// Overrides [buildAppRouter] (tests count router creations).
  final McRouterFactory? router;
  final Duration bootTimeout;
  final McRouteProbe? probe;

  @override
  State<MiniClientApp> createState() => _MiniClientAppState();
}

class _MiniClientAppState extends State<MiniClientApp> {
  /// Lets the navigator implementations reach the router once it exists.
  final RouterRef _routerRef = RouterRef();

  @override
  Widget build(BuildContext context) => McApp(
    boot: () => initializeDIContainer(
      widget.initializers?.call(_routerRef) ??
          appRootInitializers(routerRef: _routerRef),
    ),
    router:
        widget.router ??
        (initialLocation) => buildAppRouter(initialLocation: initialLocation),
    links: widget.links,
    bootTimeout: widget.bootTimeout,
    probe: widget.probe,
    routerRef: _routerRef,
    appBuilder: mediaScopeBuilder,
  );
}
