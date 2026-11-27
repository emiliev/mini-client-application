// T-0061: the preferences routes of the identity domain. The expected values
// are written out as literals here (and in the small model at the bottom); no
// test reads a constant of the package it checks.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:test/test.dart';

typedef Json = Map<String, Object?>;

const _path = '/v1/me/preferences';
const _clock = '2026-01-01T00:00:00.000Z';

MockBackend _backend({
  int seed = 42,
  MockDomain domain = const IdentityMockDomain(),
}) => MockBackend(seed: seed, domains: [domain]);

Dio _dio(MockBackend backend) =>
    backend.createDio()..options.validateStatus = (_) => true;

Dio _plain(MockBackend backend) =>
    _dio(backend)..options.responseType = ResponseType.plain;

const _readerLogin = {
  'email': 'reader@mini-client.test',
  'password': 'marvelous',
};
const _collectorLogin = {
  'email': 'collector@mini-client.test',
  'password': 'vault-7',
};

/// Signs in through the API and returns the bearer header.
Future<Map<String, String>> _signIn(
  Dio dio, [
  Map<String, String> login = _readerLogin,
]) async {
  final response = await dio.post<Json>('/v1/auth/sign-in', data: login);
  expect(response.statusCode, 200);
  return {'Authorization': 'Bearer ${response.data!['accessToken']}'};
}

Future<Response<Json>> _get(Dio dio, Map<String, String>? headers) =>
    dio.get<Json>(_path, options: Options(headers: headers));

Future<Response<Json>> _patch(
  Dio dio,
  Object? body,
  Map<String, String>? headers,
) => dio.patch<Json>(
  _path,
  data: body,
  options: Options(headers: headers),
);

/// A preferences object as the API shows it, written out by hand.
Json _prefs(
  String themeMode,
  String density,
  bool reduceMotion,
  int version,
  String updatedAt,
) => {
  'themeMode': themeMode,
  'density': density,
  'reduceMotion': reduceMotion,
  'updatedAt': updatedAt,
  'version': version,
};

String _at(int seconds) =>
    '2026-01-01T00:00:${seconds.toString().padLeft(2, '0')}.000Z';

Json _defaults() => _prefs('system', 'comfortable', false, 0, _clock);

String _code(Response<Json> r) =>
    (r.data!['error']! as Json)['code']! as String;

Directory _dirOf(String relative) {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null) '$srcDir/$workspace/$relative',
    relative,
    '.',
  ]) {
    if (File('$candidate/CONTRACT.md').existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError('$relative not found from ${Directory.current}');
}

/// Holds the requests marked `x-hold` at the transport, before the handler
/// runs, until [release]; [arrived] completes when the first one is held.
final class _HoldingAdapter implements HttpClientAdapter {
  _HoldingAdapter(this.inner);

  final HttpClientAdapter inner;
  final Completer<void> _gate = Completer<void>();
  final Completer<void> arrived = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['x-hold'] == 'yes') {
      arrived.complete();
      await _gate.future;
    }
    return inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('T-0061-AC1 determinism and seeds', () {
    test(
      'T-0061-AC1 a user who never saved gets the pinned defaults',
      () async {
        final dio = _plain(_backend());
        final auth = await _signIn(dio);

        final response = await dio.get<String>(
          _path,
          options: Options(headers: auth),
        );

        expect(response.statusCode, 200);
        expect(
          response.data,
          '{"density":"comfortable","reduceMotion":false,"themeMode":"system",'
          '"updatedAt":"$_clock","version":0}',
        );
      },
    );

    test(
      'T-0061-AC1 u-101 is seeded with themeMode dark, the rest default',
      () async {
        final dio = _dio(_backend());
        final auth = await _signIn(dio, _collectorLogin);

        final response = await _get(dio, auth);

        expect(response.statusCode, 200);
        expect(response.data, _prefs('dark', 'comfortable', false, 0, _clock));
      },
    );

    test(
      'T-0061-AC1 the seeded and default values hold in every set',
      () async {
        for (final set in ['identity.default', 'identity.empty']) {
          final dio = _dio(_backend(domain: identityFixtureSets[set]!()));
          final reader = await _get(dio, await _signIn(dio));
          final collector = await _get(
            dio,
            await _signIn(dio, _collectorLogin),
          );

          expect(reader.data, _defaults(), reason: set);
          expect(
            collector.data,
            _prefs('dark', 'comfortable', false, 0, _clock),
            reason: set,
          );
        }
      },
    );

    test(
      'T-0061-AC1 the same requests for seed 42 give byte-identical bodies',
      () async {
        Future<List<String>> run(int seed) async {
          final dio = _plain(_backend(seed: seed));
          final reader = await _signIn(dio);
          final collector = await _signIn(dio, _collectorLogin);
          Future<String> call(
            String method,
            Object? body,
            Map<String, String> auth,
          ) async {
            final r = await dio.request<String>(
              _path,
              data: body,
              options: Options(method: method, headers: auth),
            );
            return '${r.statusCode} ${r.data}';
          }

          return [
            await call('GET', null, reader),
            await call('PATCH', {'ifVersion': 0, 'themeMode': 'light'}, reader),
            await call('PATCH', {'ifVersion': 0, 'density': 'compact'}, reader),
            await call('PATCH', {'ifVersion': 1, 'reduceMotion': true}, reader),
            await call('PATCH', {'ifVersion': 1, 'themeMode': 'x'}, reader),
            await call('PATCH', {'ifVersion': 0}, collector),
            await call('PATCH', {
              'ifVersion': 'a',
              'density': 'compact',
            }, collector),
            await call('GET', null, collector),
            await call('GET', null, reader),
          ];
        }

        final first = await run(42);
        expect(await run(42), first);
        // The preferences do not depend on the seed.
        expect(await run(7), first);
        expect(first.first, startsWith('200 {'));
        expect(first.toSet().length, greaterThan(5));
      },
    );
  });

  group('T-0061-AC2 PATCH semantics', () {
    test(
      'T-0061-AC2 a partial update changes only the keys in the body',
      () async {
        final cases = <(Json, Json)>[
          (
            {'themeMode': 'light'},
            _prefs('light', 'comfortable', false, 1, _at(1)),
          ),
          (
            {'density': 'compact'},
            _prefs('system', 'compact', false, 1, _at(1)),
          ),
          (
            {'reduceMotion': true},
            _prefs('system', 'comfortable', true, 1, _at(1)),
          ),
          (
            {'themeMode': 'dark', 'reduceMotion': true},
            _prefs('dark', 'comfortable', true, 1, _at(1)),
          ),
          (
            {'themeMode': 'light', 'density': 'compact', 'reduceMotion': true},
            _prefs('light', 'compact', true, 1, _at(1)),
          ),
        ];
        for (final (patch, expected) in cases) {
          final dio = _dio(_backend());
          final auth = await _signIn(dio);

          final response = await _patch(dio, {...patch, 'ifVersion': 0}, auth);

          expect(response.statusCode, 200, reason: '$patch');
          expect(response.data, expected, reason: '$patch');
        }
      },
    );

    test(
      'T-0061-AC2 a later partial update keeps what earlier ones set',
      () async {
        final dio = _dio(_backend());
        final auth = await _signIn(dio);

        final a = await _patch(dio, {
          'ifVersion': 0,
          'themeMode': 'light',
        }, auth);
        final b = await _patch(dio, {
          'ifVersion': 1,
          'density': 'compact',
        }, auth);
        final c = await _patch(dio, {
          'ifVersion': 2,
          'reduceMotion': true,
        }, auth);
        final d = await _patch(dio, {
          'ifVersion': 3,
          'themeMode': 'dark',
        }, auth);

        expect(a.data, _prefs('light', 'comfortable', false, 1, _at(1)));
        expect(b.data, _prefs('light', 'compact', false, 2, _at(2)));
        expect(c.data, _prefs('light', 'compact', true, 3, _at(3)));
        expect(d.data, _prefs('dark', 'compact', true, 4, _at(4)));
        expect((await _get(dio, auth)).data, d.data);
      },
    );

    test('T-0061-AC2 a write of the same values still advances version and updatedAt', () async {
      final dio = _dio(_backend());
      final auth = await _signIn(dio);

      final first = await _patch(dio, {
        'ifVersion': 0,
        'themeMode': 'system',
      }, auth);
      final second = await _patch(dio, {
        'ifVersion': 1,
        'themeMode': 'system',
      }, auth);

      expect(first.data, _prefs('system', 'comfortable', false, 1, _at(1)));
      expect(second.data, _prefs('system', 'comfortable', false, 2, _at(2)));
    });

    test('T-0061-AC2 updatedAt counts a minute over sixty writes', () async {
      final dio = _dio(_backend());
      final auth = await _signIn(dio);
      Response<Json>? last;
      for (var i = 0; i < 61; i++) {
        last = await _patch(
          dio,
          {'ifVersion': i, 'reduceMotion': i.isEven},
          auth,
        );
      }

      expect(last!.data!['version'], 61);
      expect(last.data!['updatedAt'], '2026-01-01T00:01:01.000Z');
    });

    test('T-0061-AC2 a stale ifVersion is 409 with the current object and changes nothing', () async {
      final dio = _dio(_backend());
      final auth = await _signIn(dio);
      await _patch(dio, {'ifVersion': 0, 'themeMode': 'light'}, auth);
      final current = _prefs('light', 'comfortable', false, 1, _at(1));

      for (final stale in [0, 2, 5, -1]) {
        final response = await _patch(
          dio,
          {'ifVersion': stale, 'themeMode': 'dark', 'density': 'compact'},
          auth,
        );

        expect(response.statusCode, 409, reason: '$stale');
        expect(_code(response), 'version_conflict');
        expect((response.data!['error']! as Json)['current'], current);
        expect((await _get(dio, auth)).data, current, reason: 'after $stale');
      }
      // The right version still works afterwards: nothing was consumed.
      final ok = await _patch(dio, {
        'ifVersion': 1,
        'density': 'compact',
      }, auth);
      expect(ok.statusCode, 200);
      expect(ok.data, _prefs('light', 'compact', false, 2, _at(2)));
    });

    test('T-0061-AC2 the 409 body carries only the code, a message and the current object', () async {
      final dio = _dio(_backend());
      final auth = await _signIn(dio);

      final response = await _patch(dio, {
        'ifVersion': 3,
        'themeMode': 'light',
      }, auth);

      final error = response.data!['error']! as Json;
      expect(error.keys.toSet(), {'code', 'message', 'current'});
      expect(error['message'], 'The preferences are at version 0, not 3');
      expect(error['current'], _defaults());
    });

    test('T-0061-AC2 writes persist until reset, which restores the defaults and the seed', () async {
      final backend = _backend();
      final dio = _dio(backend);
      final reader = await _signIn(dio);
      final collector = await _signIn(dio, _collectorLogin);
      await _patch(dio, {'ifVersion': 0, 'themeMode': 'light'}, reader);
      await _patch(dio, {'ifVersion': 0, 'themeMode': 'system'}, collector);
      expect(
        (await _get(dio, reader)).data,
        _prefs('light', 'comfortable', false, 1, _at(1)),
      );

      backend.reset();

      expect((await _get(dio, reader)).data, _defaults());
      expect(
        (await _get(dio, collector)).data,
        _prefs('dark', 'comfortable', false, 0, _clock),
      );
    });

    test(
      'T-0061-AC2 two users signed in through the API do not see each other',
      () async {
        final dio = _dio(_backend());
        final reader = await _signIn(dio);
        final collector = await _signIn(dio, _collectorLogin);

        final r1 = await _patch(dio, {
          'ifVersion': 0,
          'density': 'compact',
        }, reader);
        final c1 = await _patch(dio, {
          'ifVersion': 0,
          'themeMode': 'light',
        }, collector);
        final r2 = await _patch(dio, {
          'ifVersion': 1,
          'reduceMotion': true,
        }, reader);

        expect(r1.data, _prefs('system', 'compact', false, 1, _at(1)));
        // The collector's version starts at 0 whatever the reader wrote.
        expect(c1.statusCode, 200);
        expect(c1.data, _prefs('light', 'comfortable', false, 1, _at(1)));
        expect(r2.data, _prefs('system', 'compact', true, 2, _at(2)));
        expect(
          (await _get(dio, collector)).data,
          _prefs('light', 'comfortable', false, 1, _at(1)),
        );
        expect((await _get(dio, reader)).data, r2.data);
        // A collector write with the reader's version is a conflict, not a hit.
        final crossed = await _patch(dio, {
          'ifVersion': 2,
          'density': 'compact',
        }, collector);
        expect(crossed.statusCode, 409);
        expect(
          (crossed.data!['error']! as Json)['current'],
          _prefs('light', 'comfortable', false, 1, _at(1)),
        );
      },
    );

    test('T-0061-AC2 sign-out then sign-in as the same user returns the saved preferences', () async {
      final dio = _dio(_backend());
      final first = await dio.post<Json>(
        '/v1/auth/sign-in',
        data: _readerLogin,
      );
      final auth = {'Authorization': 'Bearer ${first.data!['accessToken']}'};
      await _patch(dio, {
        'ifVersion': 0,
        'themeMode': 'dark',
        'density': 'compact',
      }, auth);

      final out = await dio.post<Object?>(
        '/v1/auth/sign-out',
        data: {'refreshToken': first.data!['refreshToken']},
      );
      final again = await _signIn(dio);
      final response = await _get(dio, again);

      expect(out.statusCode, 204);
      expect(again, isNot(auth));
      expect(response.data, _prefs('dark', 'compact', false, 1, _at(1)));
      // The refreshed session sees it too.
      final refreshed = await dio.post<Json>(
        '/v1/auth/refresh',
        data: {'refreshToken': 'mc-refresh-u-100-2'},
      );
      expect(
        (await _get(dio, {
          'Authorization': 'Bearer ${refreshed.data!['accessToken']}',
        })).data,
        response.data,
      );
    });

    test('T-0061-AC2 held two-client probe: two PATCHes with one ifVersion, one wins', () async {
      for (final heldWins in [false, true]) {
        final backend = _backend();
        final auth = await _signIn(_dio(backend));
        final holding = _HoldingAdapter(backend.adapter);
        final heldDio = _dio(backend)..httpClientAdapter = holding;
        final freeDio = _dio(backend);

        final held = _patch(
          heldDio,
          {'ifVersion': 0, 'themeMode': 'light'},
          {...auth, 'x-hold': 'yes'},
        );
        await holding.arrived.future;
        // The second client arrives and completes while the first is held.
        final free = await _patch(
          freeDio,
          {'ifVersion': 0, 'density': 'compact'},
          auth,
        );
        holding.release();
        final late = await held;

        expect(free.statusCode, 200, reason: 'heldWins $heldWins');
        expect(free.data, _prefs('system', 'compact', false, 1, _at(1)));
        expect(late.statusCode, 409);
        expect(_code(late), 'version_conflict');
        expect((late.data!['error']! as Json)['current'], free.data);
        // The loser changed nothing: only the winner's key is set.
        expect((await _get(freeDio, auth)).data, free.data);
      }
    });

    test('T-0061-AC2 two PATCHes in flight together: exactly one wins, whoever it is', () async {
      final backend = _backend();
      final a = _dio(backend);
      final b = _dio(backend);
      final auth = await _signIn(a);

      final results = await Future.wait([
        _patch(a, {'ifVersion': 0, 'themeMode': 'light'}, auth),
        _patch(b, {'ifVersion': 0, 'themeMode': 'dark'}, auth),
      ]);

      final statuses = results.map((r) => r.statusCode).toList()..sort();
      expect(statuses, [200, 409]);
      final winner = results.firstWhere((r) => r.statusCode == 200);
      final loser = results.firstWhere((r) => r.statusCode == 409);
      expect(winner.data!['version'], 1);
      expect((loser.data!['error']! as Json)['current'], winner.data);
      expect((await _get(a, auth)).data, winner.data);
    });

    test(
      'T-0061-AC2 a loser can re-apply on the current version and wins',
      () async {
        final dio = _dio(_backend());
        final auth = await _signIn(dio);
        await _patch(dio, {'ifVersion': 0, 'density': 'compact'}, auth);

        final lost = await _patch(dio, {
          'ifVersion': 0,
          'themeMode': 'light',
        }, auth);
        final current = (lost.data!['error']! as Json)['current']! as Json;
        final retry = await _patch(
          dio,
          {'ifVersion': current['version'], 'themeMode': 'light'},
          auth,
        );

        expect(retry.statusCode, 200);
        expect(retry.data, _prefs('light', 'compact', false, 2, _at(2)));
      },
    );

    test(
      'T-0061-AC2 a random sequence agrees with an independent model',
      () async {
        final random = Random(61);
        final dio = _dio(_backend());
        final auth = await _signIn(dio);
        final model = _Model();
        final seen = <String>{};
        const themes = ['system', 'light', 'dark', 'neon', 'Dark', ''];
        const densities = ['comfortable', 'compact', 'tight', null];
        const motions = [true, false, 'true', 0, null];

        for (var step = 0; step < 300; step++) {
          final body = <String, Object?>{};
          if (random.nextInt(10) != 0) {
            body['ifVersion'] = random.nextInt(6) == 0
                ? model.version + 1 + random.nextInt(2)
                : model.version;
          } else if (random.nextBool()) {
            body['ifVersion'] = '${model.version}';
          }
          if (random.nextInt(8) == 0) {
            body['extra'] = 1;
          }
          if (random.nextBool()) {
            body['themeMode'] = themes[random.nextInt(themes.length)];
          }
          if (random.nextBool()) {
            body['density'] = densities[random.nextInt(densities.length)];
          }
          if (random.nextBool()) {
            body['reduceMotion'] = motions[random.nextInt(motions.length)];
          }

          final response = await _patch(dio, body, auth);
          final expected = model.patch(body);

          expect(response.statusCode, expected.status, reason: '$step $body');
          if (expected.status == 200) {
            expect(response.data, model.json(), reason: '$step $body');
            seen.add('200');
          } else {
            expect(_code(response), expected.code, reason: '$step $body');
            seen.add(expected.code!);
          }
          expect(
            (await _get(dio, auth)).data,
            model.json(),
            reason: 'after $step',
          );
        }
        expect(seen, {
          '200',
          'version_conflict',
          'invalid_body',
          'unknown_key',
          'empty_patch',
          'invalid_theme_mode',
          'invalid_density',
          'invalid_reduce_motion',
        });
      },
    );
  });

  group('T-0061-AC3 validation, auth and check order', () {
    late Dio dio;
    late Map<String, String> auth;
    setUp(() async {
      dio = _dio(_backend());
      auth = await _signIn(dio);
    });

    Future<void> expectRejected(
      Object? body,
      int status,
      String code, {
      String? parameter,
    }) async {
      final response = await _patch(dio, body, auth);
      expect(response.statusCode, status, reason: '$body');
      expect(_code(response), code, reason: '$body');
      final error = response.data!['error']! as Json;
      expect(error['parameter'], parameter, reason: '$body');
      // Nothing changed, and the version did not move.
      expect((await _get(dio, auth)).data, _defaults(), reason: '$body');
    }

    test(
      'T-0061-AC3 invalid_theme_mode unless system, light or dark',
      () async {
        for (final value in <Object?>[
          'Dark',
          'LIGHT',
          'auto',
          '',
          ' dark',
          null,
          1,
          true,
          ['dark'],
        ]) {
          await expectRejected(
            {'ifVersion': 0, 'themeMode': value},
            400,
            'invalid_theme_mode',
            parameter: 'themeMode',
          );
        }
        for (final value in ['system', 'light', 'dark']) {
          final fresh = _dio(_backend());
          final freshAuth = await _signIn(fresh);
          final ok = await _patch(
            fresh,
            {'ifVersion': 0, 'themeMode': value},
            freshAuth,
          );
          expect(ok.statusCode, 200, reason: value);
          expect(ok.data!['themeMode'], value);
        }
      },
    );

    test('T-0061-AC3 invalid_density unless comfortable or compact', () async {
      for (final value in <Object?>['Compact', 'tight', '', null, 0, false]) {
        await expectRejected(
          {'ifVersion': 0, 'density': value},
          400,
          'invalid_density',
          parameter: 'density',
        );
      }
      expect(
        (await _patch(dio, {
          'ifVersion': 0,
          'density': 'comfortable',
        }, auth)).statusCode,
        200,
      );
    });

    test('T-0061-AC3 invalid_reduce_motion for a non-bool', () async {
      for (final value in <Object?>['true', 'false', 0, 1, null, [], {}]) {
        await expectRejected(
          {'ifVersion': 0, 'reduceMotion': value},
          400,
          'invalid_reduce_motion',
          parameter: 'reduceMotion',
        );
      }
      expect(
        (await _patch(dio, {
          'ifVersion': 0,
          'reduceMotion': false,
        }, auth)).statusCode,
        200,
      );
    });

    test('T-0061-AC3 unknown_key for any other key', () async {
      for (final key in [
        'theme',
        'notifications',
        'ThemeMode',
        '',
        'version',
        'updatedAt',
        'id',
      ]) {
        await expectRejected(
          {'ifVersion': 0, 'themeMode': 'light', key: 'x'},
          400,
          'unknown_key',
          parameter: key,
        );
      }
    });

    test('T-0061-AC3 invalid_body for a non-object or a missing or non-int ifVersion', () async {
      final bodies = <Object?>[
        null,
        'text',
        ['themeMode'],
        42,
        <String, Object?>{},
        {'themeMode': 'light'},
        {'ifVersion': null, 'themeMode': 'light'},
        {'ifVersion': '0', 'themeMode': 'light'},
        {'ifVersion': 0.5, 'themeMode': 'light'},
        {'ifVersion': 0.0, 'themeMode': 'light'},
        {'ifVersion': true, 'themeMode': 'light'},
        {
          'ifVersion': [0],
          'themeMode': 'light',
        },
      ];
      for (final body in bodies) {
        await expectRejected(
          body,
          400,
          'invalid_body',
          parameter: 'ifVersion',
        );
      }
    });

    test('T-0061-AC3 empty_patch when no preference key is given', () async {
      await expectRejected({'ifVersion': 0}, 400, 'empty_patch');
      await expectRejected({'ifVersion': 7}, 400, 'empty_patch');
    });

    test('T-0061-AC3 the checks run in order: auth, body, unknown key, empty, values, version', () async {
      final stale = {'ifVersion': 9};
      final checks = <(String, Object?, Map<String, String>?, int, String)>[
        // Auth first: a bad body with no bearer is 401.
        ('401 beats invalid_body', null, null, 401, 'unauthenticated'),
        (
          '401 beats unknown_key',
          {'ifVersion': 0, 'x': 1},
          null,
          401,
          'unauthenticated',
        ),
        (
          '401 beats a stale version',
          {...stale, 'themeMode': 'light'},
          null,
          401,
          'unauthenticated',
        ),
        // Body shape before everything after it.
        (
          'invalid_body beats unknown_key',
          {'ifVersion': 'a', 'x': 1},
          auth,
          400,
          'invalid_body',
        ),
        (
          'invalid_body beats invalid values',
          {'themeMode': 'x'},
          auth,
          400,
          'invalid_body',
        ),
        (
          'invalid_body beats empty_patch',
          <String, Object?>{},
          auth,
          400,
          'invalid_body',
        ),
        // Unknown keys before empty and values.
        (
          'unknown_key beats empty_patch',
          {'ifVersion': 0, 'x': 1},
          auth,
          400,
          'unknown_key',
        ),
        (
          'unknown_key beats invalid_theme_mode',
          {'ifVersion': 0, 'x': 1, 'themeMode': 'z'},
          auth,
          400,
          'unknown_key',
        ),
        (
          'unknown_key beats a stale version',
          {...stale, 'x': 1, 'themeMode': 'light'},
          auth,
          400,
          'unknown_key',
        ),
        // Empty before the version.
        ('empty_patch beats a stale version', stale, auth, 400, 'empty_patch'),
        // The values in a fixed order.
        (
          'invalid_theme_mode beats invalid_density',
          {'ifVersion': 0, 'themeMode': 'z', 'density': 'z'},
          auth,
          400,
          'invalid_theme_mode',
        ),
        (
          'invalid_theme_mode beats invalid_reduce_motion',
          {'ifVersion': 0, 'themeMode': 'z', 'reduceMotion': 1},
          auth,
          400,
          'invalid_theme_mode',
        ),
        (
          'invalid_density beats invalid_reduce_motion',
          {'ifVersion': 0, 'density': 'z', 'reduceMotion': 1},
          auth,
          400,
          'invalid_density',
        ),
        // Values before the version.
        (
          'invalid_theme_mode beats a stale version',
          {...stale, 'themeMode': 'z'},
          auth,
          400,
          'invalid_theme_mode',
        ),
        (
          'invalid_density beats a stale version',
          {...stale, 'density': 'z'},
          auth,
          400,
          'invalid_density',
        ),
        (
          'invalid_reduce_motion beats a stale version',
          {...stale, 'reduceMotion': 'z'},
          auth,
          400,
          'invalid_reduce_motion',
        ),
        // And the version last.
        (
          'a stale version alone is 409',
          {...stale, 'density': 'compact'},
          auth,
          409,
          'version_conflict',
        ),
      ];
      for (final (name, body, headers, status, code) in checks) {
        final response = await _patch(dio, body, headers);
        expect(response.statusCode, status, reason: name);
        expect(_code(response), code, reason: name);
      }
      expect((await _get(dio, auth)).data, _defaults());
    });

    test('T-0061-AC3 no bearer, an expired token and bad tokens are 401 on both routes', () async {
      final headers = <Map<String, String>?>[
        null,
        {'Authorization': 'Bearer ${expiredAccessToken('u-100')}'},
        {'Authorization': 'Bearer garbage'},
        {'Authorization': 'Bearer ${mintAccessToken('u-999', 1)}'},
        {'Authorization': 'Basic ${mintAccessToken('u-100', 1)}'},
        {'Authorization': mintAccessToken('u-100', 1)},
        {'Authorization': 'Bearer ${mintRefreshToken('u-100', 1)}'},
      ];
      for (final header in headers) {
        final get = await _get(dio, header);
        final patch = await _patch(dio, {
          'ifVersion': 0,
          'themeMode': 'light',
        }, header);
        for (final response in [get, patch]) {
          expect(response.statusCode, 401, reason: '$header');
          expect(_code(response), 'unauthenticated');
          expect(response.data.toString(), isNot(contains('themeMode')));
        }
      }
      expect((await _get(dio, auth)).data, _defaults());
    });

    test('T-0061-AC3 an expired session recovers through refresh and keeps its preferences', () async {
      final backend = _backend()..useScenario('identity.expired_token');
      final expiredDio = _dio(backend);
      final tokens = await expiredDio.post<Json>(
        '/v1/auth/sign-in',
        data: _readerLogin,
      );
      final expired = {
        'Authorization': 'Bearer ${tokens.data!['accessToken']}',
      };

      final rejected = await _patch(expiredDio, {
        'ifVersion': 0,
        'themeMode': 'dark',
      }, expired);
      final refreshed = await expiredDio.post<Json>(
        '/v1/auth/refresh',
        data: {'refreshToken': tokens.data!['refreshToken']},
      );
      final fresh = {
        'Authorization': 'Bearer ${refreshed.data!['accessToken']}',
      };

      expect(rejected.statusCode, 401);
      expect((await _get(expiredDio, fresh)).data, _defaults());
      expect(
        (await _patch(expiredDio, {
          'ifVersion': 0,
          'themeMode': 'dark',
        }, fresh)).statusCode,
        200,
      );
    });
  });

  group('T-0061-AC4 scenarios, sets and contract', () {
    test(
      'T-0061-AC4 preferences_error fails only the two preferences routes',
      () async {
        final backend = _backend()..useScenario('identity.preferences_error');
        final dio = _dio(backend);
        final auth = await _signIn(dio);

        final get = await _get(dio, auth);
        final patch = await _patch(dio, {
          'ifVersion': 0,
          'themeMode': 'light',
        }, auth);

        expect(get.statusCode, 500);
        expect(get.data, {
          'error': {
            'code': 'injected_failure',
            'message': 'Injected HTTP 500 for GET /v1/me/preferences',
          },
        });
        expect(patch.statusCode, 500);
        expect(patch.data, {
          'error': {
            'code': 'injected_failure',
            'message': 'Injected HTTP 500 for PATCH /v1/me/preferences',
          },
        });
        // Even a request that would be rejected is a 500 first.
        expect((await _patch(dio, null, null)).statusCode, 500);

        final me = await dio.get<Json>(
          '/v1/me',
          options: Options(headers: auth),
        );
        final favourite = await dio.get<Json>(
          '/v1/me/favourites/character/100000',
          options: Options(headers: auth),
        );
        final refresh = await dio.post<Json>(
          '/v1/auth/refresh',
          data: {'refreshToken': 'mc-refresh-u-100-1'},
        );
        expect(me.statusCode, 200);
        expect(favourite.statusCode, 200);
        expect(refresh.statusCode, 200);
        expect(
          (await dio.post<Json>(
            '/v1/auth/sign-in',
            data: _readerLogin,
          )).statusCode,
          200,
        );

        // The failed write wrote nothing.
        backend.useScenario(null);
        expect((await _get(dio, auth)).data, _defaults());
      },
    );

    test(
      'T-0061-AC4 preferences_conflict makes the next PATCH a 409, once',
      () async {
        final backend = _backend()
          ..useScenario('identity.preferences_conflict');
        final dio = _dio(backend);
        final auth = await _signIn(dio);
        final body = {'ifVersion': 0, 'themeMode': 'light'};

        // Reads, and requests rejected earlier, do not use it up.
        expect((await _get(dio, auth)).statusCode, 200);
        expect((await _patch(dio, body, null)).statusCode, 401);
        expect((await _patch(dio, {'ifVersion': 0}, auth)).statusCode, 400);
        expect(
          (await _patch(dio, {
            'ifVersion': 0,
            'themeMode': 'x',
          }, auth)).statusCode,
          400,
        );

        final first = await _patch(dio, body, auth);
        expect(first.statusCode, 409);
        expect(_code(first), 'version_conflict');
        expect((first.data!['error']! as Json)['current'], _defaults());
        expect((await _get(dio, auth)).data, _defaults());

        final second = await _patch(dio, body, auth);
        expect(second.statusCode, 200);
        expect(second.data, _prefs('light', 'comfortable', false, 1, _at(1)));
        final third = await _patch(dio, {
          'ifVersion': 1,
          'density': 'compact',
        }, auth);
        expect(third.statusCode, 200);
        // A genuinely stale write is still a 409 afterwards.
        expect(
          (await _patch(dio, {
            'ifVersion': 0,
            'density': 'compact',
          }, auth)).statusCode,
          409,
        );
      },
    );

    test(
      'T-0061-AC4 the conflict fires once per backend and reset arms it again',
      () async {
        Future<int> firstPatch(MockBackend backend) async {
          final dio = _dio(backend);
          final auth = await _signIn(dio);
          return (await _patch(dio, {
            'ifVersion': 0,
            'density': 'compact',
          }, auth)).statusCode!;
        }

        final one = _backend()..useScenario('identity.preferences_conflict');
        final two = _backend()..useScenario('identity.preferences_conflict');
        expect(await firstPatch(one), 409);
        expect(await firstPatch(two), 409);
        expect(await firstPatch(one), 200);

        one
          ..reset()
          ..useScenario('identity.preferences_conflict');
        final dio = _dio(one);
        final auth = await _signIn(dio);
        expect(
          (await _patch(dio, {
            'ifVersion': 0,
            'density': 'compact',
          }, auth)).statusCode,
          409,
        );
        expect(
          (await _patch(dio, {
            'ifVersion': 0,
            'density': 'compact',
          }, auth)).statusCode,
          200,
        );
      },
    );

    test('T-0061-AC4 the conflict is not consumed by another user and answers for the caller', () async {
      final backend = _backend()..useScenario('identity.preferences_conflict');
      final dio = _dio(backend);
      final reader = await _signIn(dio);
      final collector = await _signIn(dio, _collectorLogin);

      final hit = await _patch(dio, {
        'ifVersion': 0,
        'density': 'compact',
      }, collector);

      expect(hit.statusCode, 409);
      expect(
        (hit.data!['error']! as Json)['current'],
        _prefs('dark', 'comfortable', false, 0, _clock),
      );
      expect(
        (await _patch(dio, {
          'ifVersion': 0,
          'density': 'compact',
        }, reader)).statusCode,
        200,
      );
    });

    test(
      'T-0061-AC4 the sets carry the routes and the scenarios are listed',
      () async {
        for (final set in ['identity.default', 'identity.empty']) {
          final dio = _dio(_backend(domain: identityFixtureSets[set]!()));
          final auth = await _signIn(dio);
          final response = await _patch(dio, {
            'ifVersion': 0,
            'themeMode': 'light',
          }, auth);
          expect(response.statusCode, 200, reason: set);
        }
        final failing = _dio(
          _backend(domain: identityFixtureSets['identity.server_error']!()),
        );
        expect((await _get(failing, null)).statusCode, 500);
        expect((await _patch(failing, {'ifVersion': 0}, null)).statusCode, 500);

        expect(_backend().scenarioNames.toList()..sort(), [
          'identity.expired_token',
          'identity.preferences_conflict',
          'identity.preferences_error',
          'identity.server_error',
        ]);
        expect(
          _backend(domain: identityFixtureSets['identity.empty']!())
              .scenarioNames,
          isEmpty,
        );
        expect(
          IdentityMockDomain.routeManifest.where(
            (r) => r.endsWith('/v1/me/preferences'),
          ),
          ['GET /v1/me/preferences', 'PATCH /v1/me/preferences'],
        );
      },
    );

    test(
      'T-0061-AC4 identity.server_error fails the preferences routes too',
      () async {
        final backend = _backend()..useScenario('identity.server_error');
        final dio = _dio(backend);

        expect((await _get(dio, null)).statusCode, 500);
        expect((await _patch(dio, {'ifVersion': 0}, null)).statusCode, 500);
      },
    );

    test(
      'T-0061-AC4 CONTRACT.md documents the routes, codes, seeds and scenarios',
      () {
        final doc = File(
          '${_dirOf('utility/mc_fixtures_identity').path}/CONTRACT.md',
        ).readAsStringSync();
        for (final needle in [
          'GET /v1/me/preferences',
          'PATCH /v1/me/preferences',
          'identity.preferences_error',
          'identity.preferences_conflict',
          'version_conflict',
          'invalid_theme_mode',
          'invalid_density',
          'invalid_reduce_motion',
          'unknown_key',
          'invalid_body',
          'empty_patch',
          'ifVersion',
          'updatedAt',
          'themeMode',
          'reduceMotion',
        ]) {
          expect(doc, contains(needle));
        }
      },
    );

    test('T-0061-AC4 the route manifest file lists the preferences routes and scenarios', () {
      final manifest = jsonDecode(
        File(
          '${_dirOf('utility/mc_fixtures_identity').path}/fixtures/routes.json',
        ).readAsStringSync(),
      ) as Json;
      expect(
        manifest['routes'],
        containsAll(['GET /v1/me/preferences', 'PATCH /v1/me/preferences']),
      );
      expect(
        manifest['scenarios'],
        containsAll([
          'identity.preferences_error',
          'identity.preferences_conflict',
        ]),
      );
    });
  });
}

/// A model of the documented rules, written as a flat decision list rather
/// than the handler's step order.
final class _Model {
  String themeMode = 'system';
  String density = 'comfortable';
  bool reduceMotion = false;
  int version = 0;

  Json json() => {
    'themeMode': themeMode,
    'density': density,
    'reduceMotion': reduceMotion,
    'updatedAt':
        '2026-01-01T00:${(version ~/ 60).toString().padLeft(2, '0')}:'
        '${(version % 60).toString().padLeft(2, '0')}.000Z',
    'version': version,
  };

  ({int status, String? code}) patch(Map<String, Object?> body) {
    final version = body['ifVersion'];
    if (version is! int) {
      return (status: 400, code: 'invalid_body');
    }
    final others = body.keys.where((k) => k != 'ifVersion').toList();
    final known = {'themeMode', 'density', 'reduceMotion'};
    if (others.any((k) => !known.contains(k))) {
      return (status: 400, code: 'unknown_key');
    }
    if (others.isEmpty) {
      return (status: 400, code: 'empty_patch');
    }
    final theme = body['themeMode'];
    final dens = body['density'];
    final motion = body['reduceMotion'];
    if (body.containsKey('themeMode') &&
        !(theme == 'system' || theme == 'light' || theme == 'dark')) {
      return (status: 400, code: 'invalid_theme_mode');
    }
    if (body.containsKey('density') &&
        !(dens == 'comfortable' || dens == 'compact')) {
      return (status: 400, code: 'invalid_density');
    }
    if (body.containsKey('reduceMotion') && motion is! bool) {
      return (status: 400, code: 'invalid_reduce_motion');
    }
    if (version != this.version) {
      return (status: 409, code: 'version_conflict');
    }
    if (theme is String) {
      themeMode = theme;
    }
    if (dens is String) {
      density = dens;
    }
    if (motion is bool) {
      reduceMotion = motion;
    }
    this.version += 1;
    return (status: 200, code: null);
  }
}
