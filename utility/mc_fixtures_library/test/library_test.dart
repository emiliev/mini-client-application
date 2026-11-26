import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';

import 'support.dart';

Future<Map<String, Object?>> _json(
  Dio dio,
  String method,
  String path, {
  Object? body,
  String user = reader,
  int expectStatus = 200,
}) async {
  final response = await call<Map<String, Object?>>(
    dio,
    method,
    path,
    body: body,
    headers: bearer(user),
  );
  expect(response.statusCode, expectStatus, reason: '$method $path');
  return response.data ?? const {};
}

List<Map<String, Object?>> _lists(Map<String, Object?> body) =>
    (body['lists']! as List).cast<Map<String, Object?>>();

List<int> _itemIds(Map<String, Object?> detail) => [
  for (final i in (detail['items']! as List).cast<Map<String, Object?>>())
    i['id']! as int,
];

void main() {
  group('T-0047-AC1 determinism', () {
    Future<List<String>> run(int seed) async {
      final dio = plainDio(libraryBackend(seed: seed));
      final ids = comicIds(6);
      final out = <String>[];
      Future<void> go(String m, String p, [Object? b]) async => out.add(
        (await call<String>(dio, m, p, body: b, headers: bearer(reader))).data!,
      );
      await go('GET', '/v1/me/lists');
      await go('GET', '/v1/me/lists/l-1');
      await go('POST', '/v1/me/lists', {
        'name': 'Fresh',
        'visibility': 'public',
        'comicIds': ids,
      });
      await go('PUT', '/v1/me/lists/l-5/items', {
        'comicIds': ids.reversed.toList(),
      });
      await go('PUT', '/v1/me/lists/l-5', {
        'name': 'Renamed',
        'description': 'd',
        'visibility': 'private',
      });
      await go('GET', '/v1/me/lists');
      return out;
    }

    test('T-0047-AC1 the same requests give byte-identical responses for '
        'seed 42', () async {
      expect(await run(42), await run(42));
    });

    test('T-0047-AC1 replaying after reset() gives the same bytes', () async {
      final backend = libraryBackend();
      final dio = plainDio(backend);
      Future<List<String>> pass() async => [
        for (final path in ['/v1/me/lists', '/v1/me/lists/l-2'])
          (await call<String>(
            dio,
            'GET',
            path,
            headers: bearer(reader),
          )).data!,
        (await call<String>(
          dio,
          'POST',
          '/v1/me/lists',
          body: {
            'name': 'Again',
            'visibility': 'private',
            'comicIds': comicIds(2),
          },
          headers: bearer(reader),
        )).data!,
      ];
      final first = await pass();
      backend.reset();
      expect(await pass(), first);
    });
  });

  group('T-0047-AC2 CRUD', () {
    test('T-0047-AC2 the default set seeds the two users with 0 to 3 lists '
        'each', () async {
      final dio = jsonDio(libraryBackend());
      final a = _lists(await _json(dio, 'GET', '/v1/me/lists'));
      final b = _lists(
        await _json(dio, 'GET', '/v1/me/lists', user: collector),
      );
      expect([for (final l in a) l['id']], ['l-1', 'l-2', 'l-3']);
      expect([for (final l in b) l['id']], ['l-4']);
      expect(a.first.keys.toSet(), {
        'id',
        'name',
        'description',
        'visibility',
        'itemCount',
        'updatedAt',
      });
      expect([for (final l in a) l['itemCount']], [3, 2, 0]);
    });

    test('T-0047-AC2 create returns 201 with an id and the list then appears '
        'in GET /v1/me/lists', () async {
      final dio = jsonDio(libraryBackend());
      final created = await _json(
        dio,
        'POST',
        '/v1/me/lists',
        body: {
          'name': '  Origin Stories ',
          'description': 'First issues',
          'visibility': 'public',
          'comicIds': comicIds(3).reversed.toList(),
        },
        expectStatus: 201,
      );
      expect(created['id'], 'l-5');
      expect(created['name'], 'Origin Stories');
      expect(_itemIds(created), comicIds(3).reversed.toList());
      final second = await _json(
        dio,
        'POST',
        '/v1/me/lists',
        body: {'name': 'Second', 'visibility': 'private', 'comicIds': <int>[]},
        expectStatus: 201,
      );
      expect(second['id'], 'l-6', reason: 'every list gets a new id');

      final lists = _lists(await _json(dio, 'GET', '/v1/me/lists'));
      expect(lists.first['id'], 'l-6', reason: 'newest write sorts first');
      expect(lists, hasLength(5));
      final first = lists.firstWhere((l) => l['id'] == 'l-5');
      expect(first['itemCount'], 3);
      expect(first['description'], 'First issues');
      expect(first['visibility'], 'public');
      expect(
        _itemIds(await _json(dio, 'GET', '/v1/me/lists/l-5')),
        comicIds(3).reversed.toList(),
      );
    });

    test('T-0047-AC2 GET one returns the items as comic summaries in '
        'order', () async {
      final dio = jsonDio(libraryBackend());
      final detail = await _json(dio, 'GET', '/v1/me/lists/l-1');
      final items = (detail['items']! as List).cast<Map<String, Object?>>();
      expect(items, hasLength(3));
      for (final item in items) {
        expect(item.keys.toSet(), {'id', 'title', 'thumbnail'});
      }
      expect(detail['itemCount'], 3);
    });

    test('T-0047-AC2 update persists name, description and visibility, and '
        'keeps the items', () async {
      final dio = jsonDio(libraryBackend());
      final before = _itemIds(await _json(dio, 'GET', '/v1/me/lists/l-1'));
      await _json(
        dio,
        'PUT',
        '/v1/me/lists/l-1',
        body: {
          'name': ' New name ',
          'description': 'New',
          'visibility': 'private',
        },
      );
      final after = await _json(dio, 'GET', '/v1/me/lists/l-1');
      expect(after['name'], 'New name');
      expect(after['description'], 'New');
      expect(after['visibility'], 'private');
      expect(_itemIds(after), before);

      await _json(
        dio,
        'PUT',
        '/v1/me/lists/l-1',
        body: {'name': 'New name', 'visibility': 'public'},
      );
      expect(
        (await _json(dio, 'GET', '/v1/me/lists/l-1'))['description'],
        '',
        reason: 'an absent description clears it',
      );
    });

    test('T-0047-AC2 reordering keeps exactly the submitted order', () async {
      final dio = jsonDio(libraryBackend());
      final original = _itemIds(await _json(dio, 'GET', '/v1/me/lists/l-1'));
      final extra = comicIds(12).where((i) => !original.contains(i)).first;
      for (final order in [
        original.reversed.toList(),
        [original[1], extra, original[0]],
        <int>[],
        [extra],
      ]) {
        final put = await _json(
          dio,
          'PUT',
          '/v1/me/lists/l-1/items',
          body: {'comicIds': order},
        );
        expect(_itemIds(put), order);
        final get = await _json(dio, 'GET', '/v1/me/lists/l-1');
        expect(_itemIds(get), order);
        expect(get['itemCount'], order.length);
      }
    });

    test('T-0047-AC2 delete removes the list', () async {
      final dio = jsonDio(libraryBackend());
      final response = await call<Object?>(
        dio,
        'DELETE',
        '/v1/me/lists/l-2',
        headers: bearer(reader),
      );
      expect(response.statusCode, 204);
      expect(response.data, anyOf(isNull, isEmpty));
      final lists = _lists(await _json(dio, 'GET', '/v1/me/lists'));
      expect([for (final l in lists) l['id']], ['l-1', 'l-3']);
      final gone = await call<Map<String, Object?>>(
        dio,
        'GET',
        '/v1/me/lists/l-2',
        headers: bearer(reader),
      );
      expect(gone.statusCode, 404);
      expect((gone.data!['error']! as Map)['code'], 'list_not_found');
      final again = await call<Object?>(
        dio,
        'DELETE',
        '/v1/me/lists/l-2',
        headers: bearer(reader),
      );
      expect(again.statusCode, 404);
    });

    test('T-0047-AC2 the most recently edited list sorts first', () async {
      final dio = jsonDio(libraryBackend());
      await _json(
        dio,
        'PUT',
        '/v1/me/lists/l-3/items',
        body: {'comicIds': comicIds(1)},
      );
      final lists = _lists(await _json(dio, 'GET', '/v1/me/lists'));
      expect([for (final l in lists) l['id']], ['l-3', 'l-1', 'l-2']);
    });

    test('T-0047-AC2 every write persists until reset(), which restores the '
        'seed', () async {
      final backend = libraryBackend();
      final dio = jsonDio(backend);
      await _json(dio, 'DELETE', '/v1/me/lists/l-1', expectStatus: 204);
      await _json(
        dio,
        'POST',
        '/v1/me/lists',
        body: {'name': 'X', 'visibility': 'private', 'comicIds': <int>[]},
        expectStatus: 201,
      );
      await _json(
        dio,
        'PUT',
        '/v1/me/lists/l-2/items',
        body: {
          'comicIds': comicIds(4),
        },
      );
      // Persisted across requests, and across a new Dio on the same backend.
      final other = jsonDio(backend);
      var lists = _lists(await _json(other, 'GET', '/v1/me/lists'));
      expect({for (final l in lists) l['id']}, {'l-2', 'l-3', 'l-5'});
      expect(lists.firstWhere((l) => l['id'] == 'l-2')['itemCount'], 4);

      backend.reset();
      lists = _lists(await _json(jsonDio(backend), 'GET', '/v1/me/lists'));
      expect([for (final l in lists) l['id']], ['l-1', 'l-2', 'l-3']);
      expect([for (final l in lists) l['itemCount']], [3, 2, 0]);
      final next = await _json(
        dio,
        'POST',
        '/v1/me/lists',
        body: {'name': 'X', 'visibility': 'private', 'comicIds': <int>[]},
        expectStatus: 201,
      );
      expect(next['id'], 'l-5', reason: 'the id counter restarts too');
    });

    test('T-0047-AC2 user A lists are invisible to user B (404) on every '
        'route', () async {
      final dio = jsonDio(libraryBackend());
      for (final (method, path, body) in [
        ('GET', '/v1/me/lists/l-1', null),
        ('PUT', '/v1/me/lists/l-1', {'name': 'Hijack', 'visibility': 'public'}),
        ('PUT', '/v1/me/lists/l-1/items', {'comicIds': <int>[]}),
        ('DELETE', '/v1/me/lists/l-1', null),
      ]) {
        final response = await call<Map<String, Object?>>(
          dio,
          method,
          path,
          body: body,
          headers: bearer(collector),
        );
        expect(response.statusCode, 404, reason: '$method $path');
        expect((response.data!['error']! as Map)['code'], 'list_not_found');
      }
      final b = _lists(
        await _json(dio, 'GET', '/v1/me/lists', user: collector),
      );
      expect([for (final l in b) l['id']], ['l-4']);
      // A's list survived B's attempts untouched.
      final a = await _json(dio, 'GET', '/v1/me/lists/l-1');
      expect(a['name'], 'Spider-Verse Starter');
      expect(_itemIds(a), hasLength(3));
      // The reverse also holds, and a missing id is the same 404.
      final reverse = await call<Object?>(
        dio,
        'GET',
        '/v1/me/lists/l-4',
        headers: bearer(reader),
      );
      expect(reverse.statusCode, 404);
      final missing = await call<Map<String, Object?>>(
        dio,
        'GET',
        '/v1/me/lists/l-999',
        headers: bearer(reader),
      );
      expect(missing.statusCode, 404);
      expect(
        (missing.data!['error']! as Map)['code'],
        'list_not_found',
        reason: 'unknown and foreign ids look the same',
      );
    });

    test('T-0047-AC2 a user creates lists that only that user sees', () async {
      final dio = jsonDio(libraryBackend());
      final mine = await _json(
        dio,
        'POST',
        '/v1/me/lists',
        body: {'name': 'Mine', 'visibility': 'private', 'comicIds': <int>[]},
        user: collector,
        expectStatus: 201,
      );
      final id = mine['id'];
      final a = _lists(await _json(dio, 'GET', '/v1/me/lists'));
      expect(a.map((l) => l['id']), isNot(contains(id)));
      final b = _lists(
        await _json(dio, 'GET', '/v1/me/lists', user: collector),
      );
      expect(b.map((l) => l['id']), contains(id));
    });
  });

  group('T-0047-AC3 auth', () {
    final bad = <String, Map<String, String>?>{
      'no bearer': null,
      'an expired bearer': {
        'Authorization': 'Bearer ${expiredAccessToken(reader)}',
      },
      'a refresh token as bearer': {
        'Authorization': 'Bearer ${mintRefreshToken(reader, 1)}',
      },
      'an unknown user': {
        'Authorization': 'Bearer ${mintAccessToken('u-999', 1)}',
      },
      'a non-bearer scheme': {
        'Authorization': 'Basic ${mintAccessToken(reader, 1)}',
      },
    };
    for (final MapEntry(:key, :value) in bad.entries) {
      test(
        'T-0047-AC3 $key is 401 on every route, whatever the body',
        () async {
          final dio = jsonDio(libraryBackend());
          for (final (method, path, body) in [
            ...everyRoute('l-1'),
            // An invalid body and an unknown id still answer 401 first.
            ('POST', '/v1/me/lists', {'name': ''}),
            ('GET', '/v1/me/lists/l-999', null),
          ]) {
            final response = await call<Map<String, Object?>>(
              dio,
              method,
              path,
              body: body,
              headers: value,
            );
            expect(response.statusCode, 401, reason: '$key $method $path');
            expect(
              (response.data!['error']! as Map)['code'],
              'unauthenticated',
            );
          }
          // And nothing changed.
          expect(
            _lists(await _json(dio, 'GET', '/v1/me/lists')),
            hasLength(3),
          );
        },
      );
    }

    test('T-0047-AC3 a token minted without signing in is accepted, and so '
        'is one for the other user', () async {
      final dio = jsonDio(libraryBackend());
      expect(
        _lists(await _json(dio, 'GET', '/v1/me/lists', user: collector)),
        hasLength(1),
      );
    });
  });
}
