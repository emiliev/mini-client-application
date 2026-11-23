import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/src/event_bus.dart';

/// Registers the app-wide [EventBus].
class EventBusDIInitializer extends McDIInitializer {
  const EventBusDIInitializer() : super(_init);

  static void _init(GetIt getIt, String? environment) {
    getIt.registerSingleton<EventBus>(
      EventBus(),
      dispose: (bus) => bus.dispose(),
    );
  }
}
