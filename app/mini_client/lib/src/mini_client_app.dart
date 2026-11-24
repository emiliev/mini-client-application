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
List<McDIInitializer> appRootInitializers() => rootInitializers(
  config: () => rootBundle.loadString(appConfigAsset),
  storageDirectory: appStorageDirectory(),
  wirings: wiringInitializers,
);

/// The Marvel app: [McApp] over the app router.
class MiniClientApp extends StatelessWidget {
  const MiniClientApp({
    required this.links,
    this.initializers,
    this.router,
    this.bootTimeout = defaultBootTimeout,
    this.probe,
    super.key,
  });

  final PendingLinks links;

  /// Overrides [appRootInitializers] (tests).
  final List<McDIInitializer>? initializers;

  /// Overrides [buildAppRouter] (tests count router creations).
  final McRouterFactory? router;
  final Duration bootTimeout;
  final McRouteProbe? probe;

  @override
  Widget build(BuildContext context) => McApp(
    boot: () => initializeDIContainer(initializers ?? appRootInitializers()),
    router:
        router ??
        (initialLocation) => buildAppRouter(initialLocation: initialLocation),
    links: links,
    bootTimeout: bootTimeout,
    probe: probe,
  );
}
