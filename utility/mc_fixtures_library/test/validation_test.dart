import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';

import 'support.dart';

/// Every write that carries each field, with the other fields valid. Each
/// rule is pinned on every route that applies it.
enum _Route {
  create('POST', '/v1/me/lists'),
  update('PUT', '/v1/me/lists/l-1'),
  items('PUT', '/v1/me/lists/l-1/items');

  const _Route(this.method, this.path);
  final String method;
  final String path;

  bool carries(String field) => switch (this) {
    create => true,
    update => field != 'comicIds',
    items => field == 'comicIds',
  };
}

Map<String, Object?> _valid() => {
  'name': 'Valid',
  'description': 'ok',
  'visibility': 'public',
  'comicIds': comicIds(2),
};

Future<Response<Map<String, Object?>>> _send(
  Dio dio,
  _Route route,
  Map<String, Object?> body,
) => call<Map<String, Object?>>(
  dio,
  route.method,
  route.path,
  body: body,
  headers: bearer(reader),
);

void _expectError(
  Response<Map<String, Object?>> response,
  String code, {
  String? reason,
}) {
  expect(response.statusCode, 400, reason: reason);
  expect((response.data!['error']! as Map)['code'], code, reason: reason);
}

void _expectOk(Response<Map<String, Object?>> response, {String? reason}) {
  expect(response.statusCode, anyOf(200, 201), reason: reason);
}

/// Sends [value] as [field] on every route that carries it.
Future<void> _rejects(
  String field,
  Object? value,
  String code, {
  bool omit = false,
}) async {
  for (final route in _Route.values.where((r) => r.carries(field))) {
    final dio = jsonDio(libraryBackend());
    final body = _valid();
    omit ? body.remove(field) : body[field] = value;
    _expectError(
      await _send(dio, route, body),
      code,
      reason: '${route.name} $field=${omit ? '<absent>' : value}',
    );
    // A rejected write changes nothing.
    final lists =
        (await call<Map<String, Object?>>(
              dio,
              'GET',
              '/v1/me/lists',
              headers: bearer(reader),
            )).data!['lists']!
            as List;
    expect(lists, hasLength(3), reason: route.name);
    final first = (await call<Map<String, Object?>>(
      dio,
      'GET',
      '/v1/me/lists/l-1',
      headers: bearer(reader),
    )).data!;
    expect(first['name'], 'Spider-Verse Starter', reason: route.name);
    expect(first['itemCount'], 3, reason: route.name);
  }
}

Future<void> _accepts(String field, Object? value) async {
  for (final route in _Route.values.where((r) => r.carries(field))) {
    final body = _valid()..[field] = value;
    _expectOk(
      await _send(jsonDio(libraryBackend()), route, body),
      reason: '${route.name} $field=$value',
    );
  }
}

void main() {
  group('T-0047-AC3 name: 1 to 60 characters after trimming', () {
    test('T-0047-AC3 an empty name is invalid_name', () async {
      await _rejects('name', '', 'invalid_name');
    });
    test('T-0047-AC3 a blank name is invalid_name', () async {
      await _rejects('name', '  \t ', 'invalid_name');
    });
    test('T-0047-AC3 a missing name is invalid_name', () async {
      await _rejects('name', null, 'invalid_name', omit: true);
    });
    test('T-0047-AC3 a non-string name is invalid_name', () async {
      await _rejects('name', 7, 'invalid_name');
      await _rejects('name', null, 'invalid_name');
    });
    test('T-0047-AC3 61 characters are too long', () async {
      await _rejects('name', 'a' * 61, 'invalid_name');
    });
    test('T-0047-AC3 the limit is measured after trimming', () async {
      await _accepts('name', '  ${'a' * 60}  ');
      await _rejects('name', '  ${'a' * 61}  ', 'invalid_name');
    });
    test('T-0047-AC3 1 and 60 characters are valid', () async {
      await _accepts('name', 'a');
      await _accepts('name', 'a' * 60);
    });
    test('T-0047-AC3 characters are counted, not UTF-16 units', () async {
      await _accepts('name', '\u{1F4DA}' * 60);
      await _rejects('name', '\u{1F4DA}' * 61, 'invalid_name');
    });
  });

  group('T-0047-AC3 description: at most 280 characters', () {
    test('T-0047-AC3 281 characters are too long', () async {
      await _rejects('description', 'a' * 281, 'invalid_description');
    });
    test('T-0047-AC3 0, 280 characters, absent and null are valid', () async {
      await _accepts('description', '');
      await _accepts('description', 'a' * 280);
      await _accepts('description', null);
      for (final route in [_Route.create, _Route.update]) {
        final body = _valid()..remove('description');
        _expectOk(await _send(jsonDio(libraryBackend()), route, body));
      }
    });
    test('T-0047-AC3 characters are counted, not UTF-16 units', () async {
      await _accepts('description', '\u{1F4DA}' * 280);
      await _rejects('description', '\u{1F4DA}' * 281, 'invalid_description');
    });
    test(
      'T-0047-AC3 a non-string description is invalid_description',
      () async {
        await _rejects('description', 5, 'invalid_description');
        await _rejects('description', ['x'], 'invalid_description');
      },
    );
  });

  group('T-0047-AC3 visibility: private or public', () {
    test('T-0047-AC3 anything else is invalid_visibility', () async {
      for (final v in ['friends', 'Public', 'PRIVATE', '', 1, null]) {
        await _rejects('visibility', v, 'invalid_visibility');
      }
    });
    test('T-0047-AC3 a missing visibility is invalid_visibility', () async {
      await _rejects('visibility', null, 'invalid_visibility', omit: true);
    });
    test('T-0047-AC3 private and public are valid', () async {
      await _accepts('visibility', 'private');
      await _accepts('visibility', 'public');
    });
  });

  group('T-0047-AC3 comicIds: known, no duplicates, at most 100', () {
    final known = [for (final c in ComicUniverse(42).byTitle.take(101)) c.id];

    test(
      'T-0047-AC3 an unknown comic id is unknown_comic and is named',
      () async {
        await _rejects('comicIds', [known[0], 1], 'unknown_comic');
        await _rejects('comicIds', [999999999], 'unknown_comic');
        final response = await _send(
          jsonDio(libraryBackend()),
          _Route.items,
          {
            'comicIds': [known[0], 12345],
          },
        );
        expect((response.data!['error']! as Map)['comicId'], 12345);
      },
    );
    test('T-0047-AC3 a repeated comic id is duplicate_comic', () async {
      await _rejects('comicIds', [
        known[0],
        known[1],
        known[0],
      ], 'duplicate_comic');
      await _rejects('comicIds', [known[0], known[0]], 'duplicate_comic');
    });
    test('T-0047-AC3 101 comics are too_many_comics, 100 are valid', () async {
      await _rejects('comicIds', known, 'too_many_comics');
      await _accepts('comicIds', known.take(100).toList());
    });
    test('T-0047-AC3 an empty list is valid', () async {
      await _accepts('comicIds', <int>[]);
    });
    test('T-0047-AC3 a missing, non-list or non-integer comicIds is '
        'invalid_body', () async {
      await _rejects('comicIds', null, 'invalid_body', omit: true);
      await _rejects('comicIds', 'abc', 'invalid_body');
      await _rejects('comicIds', [known[0], '${known[1]}'], 'invalid_body');
      await _rejects('comicIds', [1.5], 'invalid_body');
    });
    test('T-0047-AC3 count, duplicates and unknown ids are checked in that '
        'order', () async {
      final tooMany = [...known, known.first, 1];
      await _rejects('comicIds', tooMany, 'too_many_comics');
      await _rejects('comicIds', [1, known[0], known[0]], 'duplicate_comic');
    });
  });

  group('T-0047-AC3 body and order of checks', () {
    test('T-0047-AC3 a body that is not an object is invalid_body', () async {
      for (final route in _Route.values) {
        final response = await call<Map<String, Object?>>(
          jsonDio(libraryBackend()),
          route.method,
          route.path,
          body: [1, 2],
          headers: bearer(reader),
        );
        _expectError(response, 'invalid_body', reason: route.name);
        expect(
          (response.data!['error']! as Map)['parameter'],
          'body',
          reason: route.name,
        );
      }
    });

    test('T-0047-AC3 fields are checked in the order name, description, '
        'visibility, comicIds', () async {
      final dio = jsonDio(libraryBackend());
      final all = {
        'name': '',
        'description': 'a' * 281,
        'visibility': 'x',
        'comicIds': [1],
      };
      _expectError(await _send(dio, _Route.create, all), 'invalid_name');
      all['name'] = 'ok';
      _expectError(await _send(dio, _Route.create, all), 'invalid_description');
      all['description'] = '';
      _expectError(await _send(dio, _Route.create, all), 'invalid_visibility');
      all['visibility'] = 'private';
      _expectError(await _send(dio, _Route.create, all), 'unknown_comic');
    });

    test('T-0047-AC3 an unknown or foreign list is 404 before the body is '
        'checked', () async {
      final dio = jsonDio(libraryBackend());
      for (final path in [
        '/v1/me/lists/l-999',
        '/v1/me/lists/l-4',
        '/v1/me/lists/l-999/items',
        '/v1/me/lists/l-4/items',
      ]) {
        final response = await call<Map<String, Object?>>(
          dio,
          'PUT',
          path,
          body: {'name': ''},
          headers: bearer(reader),
        );
        expect(response.statusCode, 404, reason: path);
      }
    });

    test('T-0047-AC3 a rejected create does not consume an id', () async {
      final dio = jsonDio(libraryBackend());
      _expectError(
        await _send(dio, _Route.create, _valid()..['name'] = ''),
        'invalid_name',
      );
      final ok = await _send(dio, _Route.create, _valid());
      expect(ok.data!['id'], 'l-5');
    });
  });

  test('T-0047-AC3 the limits the contract documents are the ones in code', () {
    expect(
      [nameMinLength, nameMaxLength, descriptionMaxLength, maxComicsPerList],
      [1, 60, 280, 100],
    );
    expect(visibilities, ['private', 'public']);
  });
}
