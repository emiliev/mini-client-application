import 'dart:async';

import 'package:account_wiring/src/di/di_initializer.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';

/// Registers the account group's navigator implementations (injectable;
/// Tide's boilerplate shape).
class AccountNavigatorsDIInitializer extends McDIInitializer {
  const AccountNavigatorsDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
