// Written by `mcgen wire` from every spec and package (T-0074); never edit
// it by hand. Regenerate it: `mcgen wire`.

import 'package:account_wiring/account_wiring.dart';
import 'package:app_core/app_core.dart';
import 'package:chronicle_wiring/chronicle_wiring.dart';
import 'package:commerce_wiring/commerce_wiring.dart';
import 'package:discovery_wiring/discovery_wiring.dart';
import 'package:go_router/go_router.dart';
import 'package:library_wiring/library_wiring.dart';
import 'package:mc_di/mc_di.dart';
import 'package:publishing_wiring/publishing_wiring.dart';
import 'package:universe_wiring/universe_wiring.dart';

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

/// Every wiring's routes, in group order. `buildAppRouter` nests them under
/// home (`nestUnderHome`, T-0049).
List<RouteBase> get wiringRoutes => [
  ...discoveryRoutes,
  ...universeRoutes,
  ...publishingRoutes,
  ...chronicleRoutes,
  ...commerceRoutes,
  ...libraryRoutes,
  ...accountRoutes,
];

/// Every flow `mcgen wire` generated, for the `/catalogue` debug screen
/// (T-0074): each opens from there. A flow wire could not route is
/// listed with the reason, and does not open.
const List<CatalogueEntry> catalogueEntries = [];
