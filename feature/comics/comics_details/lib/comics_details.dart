// The public surface (R4, checked by mc_arch_check and the architecture
// test): the flow, its navigator, the flow's argument type and the
// navigator's argument types. No `library;` directive (Tide's
// `unnecessary_library_directive`).
export 'package:comics_details/src/domain/model/character_id.dart'
    show CharacterId;
export 'package:comics_details/src/domain/model/comic_id.dart' show ComicId;
export 'package:comics_details/src/domain/model/creator_id.dart'
    show CreatorId;
export 'package:comics_details/src/flow/comics_details_flow.dart'
    show ComicsDetailsFlow;
export 'package:comics_details/src/navigator/comics_details_navigator.dart'
    show ComicsDetailsNavigator;
