import 'package:discovery_search/discovery_search.dart';

/// What the discovery group's typed routes build (R15): each member returns
/// a feature's `*Flow`. The route files import only this interface;
/// `DiscoveryRouteTargetsImpl` (unannotated) supplies the flows' navigators
/// and is registered by `DiscoveryWiringDIInitializer`.
///
/// Prefixed with the group (`UniverseRouteTargets`, ...) because the app
/// imports every wiring's barrel side by side (F-0040 fact 11).
abstract interface class DiscoveryRouteTargets {
  /// The search: `/search`, optionally `?q=` to start with a query.
  DiscoverySearchFlow search({String? query});
}
