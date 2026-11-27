import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

/// A store that records every asynchronous read, to tell the skip path of the
/// initializer (no read) from the restore path (one read).
final class _SpyStore extends FileStore {
  _SpyStore(super.directory);

  final List<String> reads = [];

  @override
  Future<Result<Object?, StorageFailure>> read(String key) {
    reads.add(key);
    return super.read(key);
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('mc_session_di'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<GetIt> boot([Directory? storage]) async {
    final getIt = GetIt.asNewInstance();
    for (final init in [
      StorageDIInitializer(storage ?? dir),
      const EventBusDIInitializer(),
      const SessionDIInitializer(),
    ]) {
      await init.init(getIt);
    }
    return getIt;
  }

  test(
    'T-0039-AC5 the initializer registers one session under three types',
    () async {
      final getIt = await boot();

      final session = getIt<Session>();

      expect(getIt<SessionReader>(), same(session));
      expect(getIt<SessionWriter>(), same(session));
      expect(session.isSignedIn, isFalse);
      await getIt.reset();
    },
  );

  test(
    'T-0039-AC4 the registered session restores across a boot and publishes',
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
    },
  );

  test(
    'T-0039-AC4 a missing or empty storage directory boots signed out, '
    'without reading',
    () async {
      final missing = await boot(Directory('${dir.path}/never-created'));
      final empty = await boot();

      expect(missing<SessionReader>().isSignedIn, isFalse);
      expect(empty<SessionReader>().isSignedIn, isFalse);
      expect(Directory('${dir.path}/never-created').existsSync(), isFalse);
      await missing.reset();
      await empty.reset();
    },
  );

  test('T-0039-AC4 other saved keys alone boot signed out', () async {
    await FileStore(dir).write('search_history', ['x']);

    final getIt = await boot();

    expect(getIt<SessionReader>().isSignedIn, isFalse);
    await getIt.reset();
  });

  test('T-0039-AC4 a storage path that is a file boots signed out', () async {
    final file = File('${dir.path}/not-a-dir')..writeAsStringSync('x');

    final getIt = await boot(Directory(file.path));

    expect(getIt<SessionReader>().isSignedIn, isFalse);
    await getIt.reset();
  });

  test('T-0039-AC4 a directory with other saved keys still restores', () async {
    await FileStore(dir).write('search_history', ['x']);
    await FileStore(dir).write('session', {
      'userId': 'u-9',
      'accessToken': 'a',
      'refreshToken': 'r',
    });

    final getIt = await boot();

    expect(getIt<SessionReader>().userId, 'u-9');
    await getIt.reset();
  });

  Future<(GetIt, _SpyStore)> bootSpied() async {
    final spy = _SpyStore(dir);
    final getIt = GetIt.asNewInstance();
    for (final init in <McDIInitializer>[
      McDIInitializer((g, _) => g.registerSingleton<FileStore>(spy)),
      const EventBusDIInitializer(),
      const SessionDIInitializer(),
    ]) {
      await init.init(getIt);
    }
    return (getIt, spy);
  }

  test('T-0050-AC3 (P-080) with no session file nothing is read at boot, '
      'whatever else is in the directory', () async {
    await FileStore(dir).write('search_history', ['x']);
    File('${dir.path}/stray.txt').writeAsStringSync('junk');

    final (getIt, spy) = await bootSpied();

    expect(spy.reads, isEmpty, reason: 'the skip path read the store');
    expect(getIt<SessionReader>().isSignedIn, isFalse);
    await getIt.reset();
  });

  test(
    'T-0050-AC3 (P-080) a saved session is read once and restored',
    () async {
      await FileStore(dir).write('session', {
        'userId': 'u-1',
        'accessToken': 'a',
        'refreshToken': 'r',
      });

      final (getIt, spy) = await bootSpied();

      expect(spy.reads, ['session']);
      expect(getIt<SessionReader>().userId, 'u-1');
      await getIt.reset();
    },
  );

  test(
    'T-0039-AC5 the session needs storage and the event bus first',
    () async {
      final getIt = GetIt.asNewInstance();

      await expectLater(
        Future<void>.sync(() => const SessionDIInitializer().init(getIt)),
        throwsA(anything),
      );
    },
  );
}

Future<void> pumpEventQueue() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
