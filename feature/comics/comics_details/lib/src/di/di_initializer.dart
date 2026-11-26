import 'dart:async';

import 'package:comics_details/src/di/di_initializer.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_formatters/mc_formatters.dart';

/// Registers this feature's types in its flow's own container (Tide's
/// boilerplate shape; plan 01 §3.3).
class ComicsDetailsDIInitializer extends McDIInitializer {
  const ComicsDetailsDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) async {
  // WORKAROUND (F-0040 fact 1): `mc_formatters` needs its date symbols loaded
  // once, and no root initializer does that yet (plan 01 §3.4 lists
  // `L10nCoreDIInitializer`, which does not exist). It belongs in the root
  // list and `McTestContainer`; until the TL decides, the first feature that
  // formats a date loads them here. Idempotent, and cheap after the first run.
  await initializeFormatters();
  return getIt.init(environment: environment);
}
