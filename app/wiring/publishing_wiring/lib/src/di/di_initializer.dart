import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';
import 'package:publishing_wiring/src/di/di_initializer.config.dart';

/// Registers the publishing group's navigator implementations (injectable;
/// Tide's boilerplate shape).
class PublishingNavigatorsDIInitializer extends McDIInitializer {
  const PublishingNavigatorsDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
