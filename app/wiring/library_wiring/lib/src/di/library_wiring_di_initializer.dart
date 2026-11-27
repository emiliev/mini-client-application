import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:library_wiring/src/di/di_initializer.dart';
import 'package:library_wiring/src/routes/route_targets.dart';
import 'package:library_wiring/src/routes/route_targets_impl.dart';
import 'package:mc_di/mc_di.dart';

/// The library group's root registrations: the navigator implementations
/// (injectable) and the route targets the typed routes resolve (by hand,
/// R15). Needs `RouterDIInitializer`, the session and api auth before it in
/// the root list; a navigator reaches the router only when first used.
class LibraryWiringDIInitializer extends McDIInitializer {
  const LibraryWiringDIInitializer() : super(_init);

  static FutureOr<void> _init(GetIt getIt, String? environment) async {
    await const LibraryNavigatorsDIInitializer().init(getIt);
    getIt.registerLazySingleton<LibraryRouteTargets>(
      () => LibraryRouteTargetsImpl(
        readingListEditor: getIt<ReadingListEditorNavigator>(),
      ),
    );
  }
}
