import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_wiring/src/di/di_initializer.config.dart';

/// Registers the universe group's navigator implementations (injectable;
/// Tide's boilerplate shape).
class UniverseNavigatorsDIInitializer extends McDIInitializer {
  const UniverseNavigatorsDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
