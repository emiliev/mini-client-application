import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_storage/src/file_store.dart';

/// Registers a [FileStore] under [directory]. The app supplies the directory
/// (its documents path), keeping this package free of plugins.
class StorageDIInitializer extends McDIInitializer {
  StorageDIInitializer(Directory directory) : super(_init(directory));

  static GetItInitializer _init(Directory directory) =>
      (GetIt getIt, String? environment) {
        getIt.registerSingleton<FileStore>(FileStore(directory));
      };
}
