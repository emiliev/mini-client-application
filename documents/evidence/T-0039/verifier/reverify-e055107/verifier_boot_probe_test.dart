// T-0039 Verifier re-verification probe (not part of the branch): which
// path SessionDIInitializer takes. A FileStore spy counts async reads.
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

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

  setUp(() => dir = Directory.systemTemp.createTempSync('mc_v_boot'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<(GetIt, _SpyStore)> boot() async {
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

  test('V-B1 an unrelated key in the directory: no async read at boot', () async {
    await FileStore(dir).write('search_history', ['x']);
    File('${dir.path}/stray.txt').writeAsStringSync('junk');

    final (getIt, spy) = await boot();

    expect(spy.reads, isEmpty, reason: 'took the real-I/O path');
    expect(getIt<SessionReader>().isSignedIn, isFalse);
    await getIt.reset();
  });

  test('V-B2 a saved session: one read, restored', () async {
    await FileStore(dir).write('session', {
      'userId': 'u-1',
      'accessToken': 'a',
      'refreshToken': 'r',
    });

    final (getIt, spy) = await boot();

    expect(spy.reads, ['session']);
    expect(getIt<SessionReader>().userId, 'u-1');
    await getIt.reset();
  });

  test('V-B3 an empty directory: no read', () async {
    final (getIt, spy) = await boot();

    expect(spy.reads, isEmpty);
    await getIt.reset();
  });

  test('V-B4 a corrupt session file: read, signed out, heals', () async {
    await FileStore(dir).write('session', 1);
    File('${dir.path}/73657373696f6e.json').writeAsStringSync('{broken');

    final (getIt, spy) = await boot();

    expect(spy.reads, ['session']);
    expect(getIt<SessionReader>().isSignedIn, isFalse);
    await getIt<SessionWriter>().signIn(
      userId: 'u-2',
      tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    expect((await Session.restore(FileStore(dir))).userId, 'u-2');
    await getIt.reset();
  });
}
