// The public surface (R4, checked by mc_arch_check and the architecture
// test): the flow, its navigator, the flow's argument type and the
// navigator's argument types. No `library;` directive (Tide's
// `unnecessary_library_directive`).
export 'package:store_home/src/domain/model/category_id.dart' show CategoryId;
export 'package:store_home/src/domain/model/comic_id.dart' show ComicId;
export 'package:store_home/src/flow/store_home_flow.dart' show StoreHomeFlow;
export 'package:store_home/src/navigator/store_home_navigator.dart'
    show StoreHomeNavigator;
