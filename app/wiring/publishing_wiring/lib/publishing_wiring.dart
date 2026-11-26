// The publishing group's app layer (plan 01 §3.4): typed routes, navigator
// implementations and the DI initializer. Features never see any of it.
import 'package:go_router/go_router.dart';
import 'package:publishing_wiring/src/routes/comics_routes.dart';
import 'package:publishing_wiring/src/routes/creators_routes.dart';

export 'package:publishing_wiring/src/di/di_initializer.dart'
    show PublishingNavigatorsDIInitializer;
export 'package:publishing_wiring/src/di/publishing_wiring_di_initializer.dart'
    show PublishingWiringDIInitializer;
export 'package:publishing_wiring/src/flows/creator_details_placeholder_flow.dart'
    show CreatorDetailsPlaceholderFlow;
export 'package:publishing_wiring/src/routes/comics_routes.dart'
    show ComicDetailsRoute;
export 'package:publishing_wiring/src/routes/creators_routes.dart'
    show CreatorDetailsRoute;
export 'package:publishing_wiring/src/routes/route_targets.dart'
    show PublishingRouteTargets;
export 'package:publishing_wiring/src/sign_in/fixture_sign_in_sheet.dart'
    show fixtureSignInButtonKey, fixtureSignInCancelKey, fixtureSignInSheetKey;

/// The publishing group's routes (comics and creators; series later).
List<RouteBase> get publishingRoutes => <RouteBase>[
  ...comicsRoutes,
  ...creatorsRoutes,
];
