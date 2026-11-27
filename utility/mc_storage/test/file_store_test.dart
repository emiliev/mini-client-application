import 'dart:io';

import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

StorageFailure? _failureOf<T>(Result<T, StorageFailure> r) =>
    r.fold<StorageFailure?>((_) => null, (f) => f);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mc_storage_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('T-0020-AC4 a value written is read back by a new store', () async {
    final written = await FileStore(dir).write('prefs', {'theme': 'dark'});
    expect(_failureOf(written), isNull);
    final read = await FileStore(Directory(dir.path)).read('prefs');
    expect(read.getOrNull(), {'theme': 'dark'});
  });

  test('T-0039-AC4 existsSync tells a saved key from a missing one', () async {
    final store = FileStore(dir);
    expect(store.existsSync('k'), isFalse);
    await store.write('k', 1);
    expect(store.existsSync('k'), isTrue);
    await store.delete('k');
    expect(store.existsSync('k'), isFalse);
    expect(FileStore(Directory('${dir.path}/never')).existsSync('k'), isFalse);
  });

  test('T-0020-AC4 a missing key reads as null', () async {
    final read = await FileStore(dir).read('nope');
    expect(_failureOf(read), isNull);
    expect(read.getOrNull(), isNull);
  });

  test('T-0020-AC4 a corrupt file is a typed failure, not a crash', () async {
    final store = FileStore(dir);
    await store.write('bad', 1);
    final file = dir.listSync().whereType<File>().single;
    file.writeAsStringSync('{not json');
    final failure = _failureOf(await store.read('bad'));
    expect(failure, isA<StorageFailure>());
    expect(failure!.key, 'bad');
  });

  test('T-0020-AC4 overlapping writes leave the last value, whole', () async {
    final store = FileStore(dir);
    final results = await Future.wait([
      for (var i = 0; i < 20; i++) store.write('k', {'n': i, 'pad': 'x' * 500}),
    ]);
    expect(results.every((r) => _failureOf(r) == null), isTrue);
    final read = await FileStore(dir).read('k');
    expect((read.getOrNull()! as Map)['n'], 19);
    expect(
      dir.listSync().where((e) => e.path.endsWith('.tmp')),
      isEmpty,
      reason: 'no temp files are left behind',
    );
  });

  test('T-0020-AC4 delete removes the value and is idempotent', () async {
    final store = FileStore(dir);
    await store.write('k', 1);
    expect(_failureOf(await store.delete('k')), isNull);
    expect((await store.read('k')).getOrNull(), isNull);
    expect(_failureOf(await store.delete('k')), isNull);
  });

  test(
    'T-0020-AC4 a read racing a delete is not reported as corrupt',
    () async {
      final store = FileStore(dir);
      for (var i = 0; i < 50; i++) {
        await store.write('k', i);
        final results = await Future.wait([store.read('k'), store.delete('k')]);
        expect(
          _failureOf(results[0] as Result<Object?, StorageFailure>),
          isNull,
        );
      }
    },
  );

  test('T-0020-AC4 keys differing only by case use distinct files', () async {
    final store = FileStore(dir);
    await store.write('Key', 1);
    await store.write('key', 2);
    expect((await store.read('Key')).getOrNull(), 1);
    expect((await store.read('key')).getOrNull(), 2);
  });

  test(
    'T-0020-AC4 a write into an unusable directory is a typed failure',
    () async {
      final blocker = File('${dir.path}/file')..writeAsStringSync('x');
      final failure = _failureOf(
        await FileStore(Directory('${blocker.path}/sub')).write('k', 1),
      );
      expect(failure, isA<StorageFailure>());
    },
  );

  test('T-0020-AC4 a directory at the key path is a typed failure', () async {
    final store = FileStore(dir);
    await store.write('k', 1);
    final file = dir.listSync().whereType<File>().single;
    file.deleteSync();
    Directory(file.path).createSync();
    final failure = _failureOf(await store.read('k'));
    expect(failure, isA<StorageFailure>());
    expect(failure!.key, 'k');
  });

  group('T-0063-AC6 synchronous read and write (the appearance)', () {
    test('T-0063-AC6 writeSync is on disk when it returns, and readSync and '
        'read see it', () async {
      final store = FileStore(Directory('${dir.path}/new'));
      expect(
        _failureOf(store.writeSync('prefs', {'themeMode': 'dark'})),
        isNull,
      );
      // No temp file left behind, and no write still running.
      final files = Directory('${dir.path}/new').listSync();
      expect(files, hasLength(1));
      expect(files.single.path, endsWith('.json'));
      expect(
        FileStore(Directory('${dir.path}/new')).readSync('prefs').getOrNull(),
        {'themeMode': 'dark'},
      );
      expect((await store.read('prefs')).getOrNull(), {'themeMode': 'dark'});
    });

    test('T-0063-AC6 a second writeSync replaces the value', () {
      final store = FileStore(dir)
        ..writeSync('k', 1)
        ..writeSync('k', 2);
      expect(store.readSync('k').getOrNull(), 2);
      expect(dir.listSync(), hasLength(1));
    });

    test('T-0063-AC6 readSync: a missing key is null, a corrupt file a '
        'typed failure', () {
      final store = FileStore(dir);
      expect(_failureOf(store.readSync('nope')), isNull);
      expect(store.readSync('nope').getOrNull(), isNull);
      store.writeSync('bad', 1);
      dir.listSync().whereType<File>().single.writeAsStringSync('{not json');
      final failure = _failureOf(store.readSync('bad'));
      expect(failure, isA<StorageFailure>());
      expect(failure!.key, 'bad');
    });

    test('T-0063-AC6 a writeSync that cannot rename into place is a typed '
        'failure and leaves no temp file', () {
      final store = FileStore(dir)..writeSync('k', 'old');
      final file = dir.listSync().whereType<File>().single;
      // A directory where the value's file goes: the rename fails.
      file.deleteSync();
      Directory(file.path).createSync();
      final failure = _failureOf(store.writeSync('k', 'new'));
      expect(failure, isA<StorageFailure>());
      expect(failure!.key, 'k');
      expect(
        dir.listSync().where((e) => e.path.endsWith('.tmp')),
        isEmpty,
        reason: 'the temp file is removed',
      );
    });

    test('T-0063-AC6 writeSync under a file (no directory) is a typed '
        'failure', () {
      final blocker = File('${dir.path}/file')..writeAsStringSync('x');
      final failure = _failureOf(
        FileStore(Directory('${blocker.path}/sub')).writeSync('k', 1),
      );
      expect(failure, isA<StorageFailure>());
    });
  });
}
