import 'dart:io';

import 'package:account_wiring/account_wiring.dart';
import 'package:app_core/app_core.dart';
import 'package:chronicle_wiring/chronicle_wiring.dart';
import 'package:commerce_wiring/commerce_wiring.dart';
import 'package:discovery_wiring/discovery_wiring.dart';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:library_wiring/library_wiring.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_storage/mc_storage.dart';
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
    this.storageDirectory,
    super.key,
  });

  final PendingLinks links;

  /// Where the saved appearance is read from before boot, to paint the boot
  /// page in its theme (the app's storage directory unless given; tests that
  /// boot on their own directory pass it).
  final Directory? storageDirectory;

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

  /// The theme mode the boot page shows: the saved one, read synchronously
  /// (`mc_storage`), so a saved Dark does not flash light (review round).
  /// Once boot is ready, `McApp` drives it from the live appearance.
  late final McThemeModeController _themeMode = McThemeModeController(
    (savedAppearance(
              FileStore(widget.storageDirectory ?? appStorageDirectory()),
            ) ??
            AppearancePreferences.defaults)
        .flutterThemeMode,
  );

  @override
  void dispose() {
    _themeMode.dispose();
    super.dispose();
  }

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
    themeMode: _themeMode,
    bootTimeout: widget.bootTimeout,
    probe: widget.probe,
    routerRef: _routerRef,
    appBuilder: mediaScopeBuilder,
  );
}
