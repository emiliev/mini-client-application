import 'dart:async';
import 'dart:io';

import 'package:mc_paging/mc_paging.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late FileStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('mc_paging_history');
    store = FileStore(dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('T-0030-AC5: a repeated query moves to the front, once', () async {
    final sut = SearchHistory(store);
    await sut.add('thor');
    await sut.add('hulk');

    final result = await sut.add('thor');

    expect(result.getOrNull(), ['thor', 'hulk']);
  });

  test('T-0030-AC5: 12 distinct queries keep the 10 most recent', () async {
    final sut = SearchHistory(store);
    for (var i = 1; i <= 12; i++) {
      await sut.add('q$i');
    }

    final loaded = (await sut.load()).getOrNull();

    expect(loaded, [for (var i = 12; i >= 3; i--) 'q$i']);
  });

  test(
    'T-0030-AC5: the history survives a new instance on the same store',
    () async {
      await SearchHistory(store).add('thor');
      await SearchHistory(store).add('loki');

      final loaded = await SearchHistory(FileStore(dir)).load();

      expect(loaded.getOrNull(), ['loki', 'thor']);
    },
  );

  test(
    'T-0030-AC5: blank queries are ignored and the cap is configurable',
    () async {
      final sut = SearchHistory(store, cap: 2);
      await sut.add('a');
      await sut.add('  ');
      await sut.add(' b ');
      await sut.add('c');

      expect((await sut.load()).getOrNull(), ['c', 'b']);
    },
  );

  test('T-0030-AC5: overlapping adds all land', () async {
    final sut = SearchHistory(store);

    await Future.wait([sut.add('a'), sut.add('b'), sut.add('c')]);

    expect((await sut.load()).getOrNull(), ['c', 'b', 'a']);
  });

  test('T-0030-AC5: clear empties the history', () async {
    final sut = SearchHistory(store);
    await sut.add('a');

    await sut.clear();

    expect((await sut.load()).getOrNull(), isEmpty);
  });

  test('T-0030-AC5: a value of the wrong shape reads as empty', () async {
    await store.write('search_history', {'not': 'a list'});

    expect((await SearchHistory(store).load()).getOrNull(), isEmpty);
  });

  test('T-0030-AC5: a corrupt file loads as empty and add heals it', () async {
    _writeCorrupt(dir);
    final sut = SearchHistory(store);

    final loaded = await sut.load();
    final added = await sut.add('x');

    expect(loaded.getOrNull(), isEmpty);
    expect(added.getOrNull(), ['x']);
    expect((await SearchHistory(store).load()).getOrNull(), ['x']);
  });

  test(
    'T-0030-AC5: clear that is not awaited runs after earlier adds',
    () async {
      final sut = SearchHistory(store);
      await sut.add('a');

      unawaited(sut.add('c'));
      await sut.clear();

      expect((await sut.load()).getOrNull(), isEmpty);
    },
  );

  test('T-0030-AC5: add after clear starts a fresh history', () async {
    final sut = SearchHistory(store);
    await sut.add('a');

    unawaited(sut.clear());
    final added = await sut.add('b');

    expect(added.getOrNull(), ['b']);
  });

  test(
    'T-0030-AC5: load applies the cap to an oversized stored list',
    () async {
      await store.write('search_history', ['a', 'b', 'c', 'd']);

      final loaded = await SearchHistory(store, cap: 2).load();

      expect(loaded.getOrNull(), ['a', 'b']);
    },
  );
}

void _writeCorrupt(Directory dir) {
  File('${dir.path}/${_hexKey('search_history')}.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('{broken');
}

String _hexKey(String key) =>
    key.codeUnits.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
