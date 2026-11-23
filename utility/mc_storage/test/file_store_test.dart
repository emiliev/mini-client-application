import 'dart:io';

import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mc_storage_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('T-0020-AC4 a value written is read back by a new store', () async {
    await FileStore(dir).write('prefs', {'theme': 'dark', 'n': 2});
    final read = await FileStore(Directory(dir.path)).read('prefs');
    expect(read.getOrNull(), {'theme': 'dark', 'n': 2});
  });

  test('T-0020-AC4 a missing key reads as null', () async {
    final read = await FileStore(dir).read('nope');
    expect(read.getOrElse(() => 'failed'), isNull);
  });

  test('T-0020-AC4 a corrupt file is a typed failure, not a crash', () async {
    File('${dir.path}/bad.json').writeAsStringSync('{not json');
    final read = await FileStore(dir).read('bad');
    final failure = read.fold<StorageFailure?>((_) => null, (f) => f);
    expect(failure, isA<StorageFailure>());
    expect(failure!.key, 'bad');
  });
}
