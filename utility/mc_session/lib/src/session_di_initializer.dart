import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_session/src/session.dart';
import 'package:mc_session/src/session_ports.dart';
import 'package:mc_storage/mc_storage.dart';

/// Opens the saved session and registers it as [Session], [SessionReader] and
/// [SessionWriter]. List `StorageDIInitializer` and `EventBusDIInitializer`
/// first.
///
/// Reading the saved session is real file I/O. When the session's own file
/// does not exist (a first launch, and every widget test with a fresh temp
/// directory) nothing can be restored, so the read is skipped: that keeps boot
/// free of I/O, which a `testWidgets` body under fake async cannot await
/// (F-0038). Other saved keys do not matter. If the check itself fails, the
/// session is read the normal way, which reports a bad store as signed out.
class SessionDIInitializer extends McDIInitializer {
  const SessionDIInitializer() : super(_init);

  static Future<void> _init(GetIt getIt, String? environment) async {
    final store = getIt<FileStore>();
    final bus = getIt<EventBus>();
    bool nothingSaved;
    try {
      nothingSaved = !store.existsSync(Session.defaultKey);
    } on Object {
      nothingSaved = false;
    }
    final session = nothingSaved
        ? Session.empty(store, bus: bus)
        : await Session.restore(store, bus: bus);
    getIt
      ..registerSingleton<Session>(session, dispose: (s) => s.dispose())
      ..registerSingleton<SessionReader>(session)
      ..registerSingleton<SessionWriter>(session);
  }
}
