import 'package:discovery_search/discovery_search.dart';
import 'package:discovery_wiring/src/routes/route_targets.dart';

/// Builds each route's flow from the feature barrels (R15: unannotated, so no
/// generator reads it).
class DiscoveryRouteTargetsImpl implements DiscoveryRouteTargets {
  const DiscoveryRouteTargetsImpl({
    required DiscoverySearchNavigator discoverySearch,
  }) : _discoverySearch = discoverySearch;

  final DiscoverySearchNavigator _discoverySearch;

  @override
  DiscoverySearchFlow search({String? query}) =>
      DiscoverySearchFlow(navigator: _discoverySearch, initialQuery: query);
}
