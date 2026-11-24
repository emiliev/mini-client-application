import 'package:di_sample/src/di/di_initializer.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_di/mc_di.dart';

@InjectableInit(initializerName: 'init')
Future<void> _init(GetIt getIt, String? environment) async {
  await getIt.init(environment: environment);
}

/// The package's DI initializer, run by `initializeDIContainer`.
const McDIInitializer diSampleDIInitializer = McDIInitializer(_init);
