// The public surface (R4, checked by mc_arch_check and the architecture
// test): the flow, its navigator, the flow's argument type and the
// navigator's argument types. No `library;` directive (Tide's
// `unnecessary_library_directive`).
export 'package:characters_details/src/domain/model/character_id.dart'
    show CharacterId;
export 'package:characters_details/src/domain/model/comic_id.dart' show ComicId;
export 'package:characters_details/src/flow/characters_details_flow.dart'
    show CharacterDetailsFlow;
export 'package:characters_details/src/navigator/characters_details_navigator.dart'
    show CharacterDetailsNavigator;
