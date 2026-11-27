import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';
import 'package:settings_appearance/src/di/di_initializer.config.dart';

/// Registers this feature's types in its flow's own container (Tide's
/// boilerplate shape; plan 01 §3.3).
class SettingsAppearanceDIInitializer extends McDIInitializer {
  const SettingsAppearanceDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
