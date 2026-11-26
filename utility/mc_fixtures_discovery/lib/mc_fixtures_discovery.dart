export 'package:mc_fixtures_discovery/src/domain.dart'
    show
        DiscoveryMockDomain,
        EmptyDiscoveryDomain,
        FailingDiscoveryDomain,
        IndexedDiscoveryDomain,
        discoveryRouteManifest;
export 'package:mc_fixtures_discovery/src/fixture_sets.dart'
    show discoveryFixtureSets;
export 'package:mc_fixtures_discovery/src/handlers/search_handlers.dart'
    show defaultLimit, maxLimit, minQueryLength, suggestionCount;
export 'package:mc_fixtures_discovery/src/search/index.dart'
    show
        MatchTier,
        SearchEntry,
        SearchIndex,
        SearchMatch,
        compareMatches,
        matchTier,
        searchTypes;
export 'package:mc_fixtures_discovery/src/search/normalize.dart'
    show foldText;
