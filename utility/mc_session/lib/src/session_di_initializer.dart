import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_session/src/session.dart';
import 'package:mc_session/src/session_ports.dart';
import 'package:mc_storage/mc_storage.dart';

/// Opens the saved session (async) and registers it as [Session],
/// [SessionReader] and [SessionWriter]. List `StorageDIInitializer` and
/// `EventBusDIInitializer` first.
class SessionDIInitializer extends McDIInitializer {
  const SessionDIInitializer() : super(_init);

  static Future<void> _init(GetIt getIt, String? environment) async {
    final session = await Session.restore(
      getIt<FileStore>(),
      bus: getIt<EventBus>(),
    );
    getIt
      ..registerSingleton<Session>(session, dispose: (s) => s.dispose())
      ..registerSingleton<SessionReader>(session)
      ..registerSingleton<SessionWriter>(session);
  }
}
