import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:library_reading_list_editor/src/di/di_initializer.config.dart';
import 'package:mc_di/mc_di.dart';

/// Registers this feature's types in its flow's own container (Tide's
/// boilerplate shape; plan 01 §3.3).
class ReadingListEditorDIInitializer extends McDIInitializer {
  const ReadingListEditorDIInitializer() : super(_init);
}

@InjectableInit()
FutureOr<GetIt> _init(GetIt getIt, String? environment) =>
    getIt.init(environment: environment);
