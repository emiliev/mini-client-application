// The public surface (R4, checked by mc_arch_check and the architecture
// test): the flow, its navigator and the navigator's argument types. No
// `library;` directive (Tide's `unnecessary_library_directive`).
export 'package:discovery_search/src/domain/model/character_id.dart'
    show CharacterId;
export 'package:discovery_search/src/domain/model/comic_id.dart' show ComicId;
export 'package:discovery_search/src/flow/discovery_search_flow.dart'
    show DiscoverySearchFlow;
export 'package:discovery_search/src/navigator/discovery_search_navigator.dart'
    show DiscoverySearchNavigator;
