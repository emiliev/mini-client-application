import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:library_wiring/src/di/di_initializer.config.dart';
import 'package:mc_di/mc_di.dart';

/// Registers the library group's navigator implementations (injectable;
/// Tide's boilerplate shape).
class LibraryNavigatorsDIInitializer extends McDIInitializer {
  const LibraryNavigatorsDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
