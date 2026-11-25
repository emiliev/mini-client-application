import 'dart:async';

import 'package:characters_list/src/di/di_initializer.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';

/// Registers this feature's types in its flow's own container (Tide's
/// boilerplate, verbatim shape; plan 01 §3.3).
class CharactersListDIInitializer extends McDIInitializer {
  const CharactersListDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
