import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('mc_session_di'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<GetIt> boot() async {
    final getIt = GetIt.asNewInstance();
    for (final init in [
      StorageDIInitializer(dir),
      const EventBusDIInitializer(),
      const SessionDIInitializer(),
    ]) {
      await init.init(getIt);
    }
    return getIt;
  }

  test('T-0039-AC5 the initializer registers one session under three types',
      () async {
    final getIt = await boot();

    final session = getIt<Session>();

    expect(getIt<SessionReader>(), same(session));
    expect(getIt<SessionWriter>(), same(session));
    expect(session.isSignedIn, isFalse);
    await getIt.reset();
  });

  test('T-0039-AC4 the registered session restores across a boot and publishes',
      () async {
    final first = await boot();
    final events = <SessionChanged>[];
    first<EventBus>().on<SessionChanged>().listen(events.add);
    await first<SessionWriter>().signIn(
      userId: 'u-1',
      tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    await pumpEventQueue();
    await first.reset();

    final second = await boot();

    expect(events, const [SessionChanged(AuthStatus.signedIn)]);
    expect(second<SessionReader>().userId, 'u-1');
    await second.reset();
  });

  test('T-0039-AC5 the session needs storage and the event bus first',
      () async {
    final getIt = GetIt.asNewInstance();

    await expectLater(
      Future<void>.sync(() => const SessionDIInitializer().init(getIt)),
      throwsA(anything),
    );
  });
}

Future<void> pumpEventQueue() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
