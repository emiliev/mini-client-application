import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/src/monitoring.dart';
import 'package:mc_monitoring/src/sinks.dart';

/// Registers [Monitoring] with the given sinks (default: console).
class MonitoringDIInitializer extends McDIInitializer {
  MonitoringDIInitializer({List<MonitoringSink>? sinks})
    : super(_init(sinks ?? [ConsoleSink()]));

  static GetItInitializer _init(List<MonitoringSink> sinks) =>
      (GetIt getIt, String? environment) {
        getIt.registerSingleton<Monitoring>(Monitoring(sinks));
      };
}
