import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'oracle.dart';
import 'support.dart';

MockBackend _backend(String set) =>
    MockBackend(domains: [editorialFixtureSets[set]!()]);

typedef _Call = (String, String, Map<String, Object?>?, Object?);

/// Every route with valid and invalid inputs.
Future<List<_Call>> _calls() async {
  final round = await fetchRound(jsonDio(triviaBackend()));
  return [
    ('GET', '/v1/trivia/categories', null, null),
    (
      'GET',
      '/v1/trivia/rounds',
      {'category': 'all', 'difficulty': 'easy', 'seed': 42},
      null,
    ),
    (
      'GET',
      '/v1/trivia/rounds',
      {'category': 'comics', 'difficulty': 'hard', 'seed': 5},
      null,
    ),
    (
      'GET',
      '/v1/trivia/rounds',
      {'category': 'nope', 'difficulty': 'easy', 'seed': 42},
      null,
    ),
    (
      'POST',
      '/v1/me/trivia/results',
      null,
      {
        'roundId': round['roundId'],
        'answers': answersFor(round, parseAnswers('C0x10')),
      },
    ),
    (
      'POST',
      '/v1/me/trivia/results',
      null,
      {'roundId': 'nope', 'answers': <Object?>[]},
    ),
    ('GET', '/v1/me/trivia/best', null, null),
  ];
}

Future<Response<Object?>> _send(Dio dio, _Call c) => call<Object?>(
  dio,
  c.$1,
  c.$2,
  query: c.$3,
  body: c.$4,
  headers: bearer(reader),
);

void main() {
  test('T-0060-AC4 the fixture sets are default, empty, server_error', () {
    expect(editorialFixtureSets.keys, [
      'trivia.default',
      'trivia.empty',
      'trivia.server_error',
    ]);
    expect(editorialFixtureSets['trivia.default']!(), isA<TriviaMockDomain>());
    expect(editorialFixtureSets['trivia.empty']!(), isA<EmptyTriviaDomain>());
    expect(
      editorialFixtureSets['trivia.server_error']!(),
      isA<FailingTriviaDomain>(),
    );
    expect(triviaRouteManifest, TriviaMockDomain.routeManifest);
    expect(const EmptyTriviaDomain().scenarios, isEmpty);
    expect(const FailingTriviaDomain().scenarios, isEmpty);
    expect(const TriviaMockDomain().scenarios.keys.toList()..sort(), [
      'trivia.empty',
      'trivia.server_error',
      'trivia.slow',
    ]);
    for (final domain in [
      const TriviaMockDomain(),
      const EmptyTriviaDomain(),
      const FailingTriviaDomain(),
    ]) {
      expect(domain.name, 'trivia');
    }
  });

  test('T-0060-AC4 trivia.default serves the categories, rounds and seeded '
      'bests', () async {
    final dio = jsonDio(_backend('trivia.default'));
    final categories =
        (await _send(dio, (
              'GET',
              '/v1/trivia/categories',
              null,
              null,
            ))).data!
            as Json;
    expect(
      [
        for (final c in (categories['categories']! as List).cast<Json>())
          c['id'],
      ],
      ['all', 'characters', 'comics', 'creators'],
    );
    expect(await bestOf(dio), seededBest[reader]);
  });

  test('T-0060-AC4 trivia.empty has no categories and no rounds, but auth '
      'and validation work', () async {
    final dio = jsonDio(_backend('trivia.empty'));
    final categories = await _send(dio, (
      'GET',
      '/v1/trivia/categories',
      null,
      null,
    ));
    expect(categories.data, {'categories': <Object?>[]});
    for (final category in ['all', 'characters', 'comics', 'creators']) {
      final response = await call<Json>(
        dio,
        'GET',
        '/v1/trivia/rounds',
        query: {'category': category, 'difficulty': 'easy', 'seed': 42},
      );
      expect(response.statusCode, 400, reason: category);
      expect((response.data!['error']! as Json)['code'], 'unknown_category');
      expect(
        (response.data!['error']! as Json)['message'],
        'there are no categories',
        reason: category,
      );
    }
    final results = await postResult(dio, {
      'roundId': 'r-all-easy-42',
      'answers': <Object?>[],
    });
    expect((results.data!['error']! as Json)['code'], 'unknown_round');
    expect(await bestOf(dio), isEmpty);
    expect(await bestOf(dio, user: collector), isEmpty);
    final noAuth = await call<Json>(dio, 'GET', '/v1/me/trivia/best');
    expect(noAuth.statusCode, 401);
    final badBody = await call<Json>(
      dio,
      'POST',
      '/v1/me/trivia/results',
      body: 'x',
      headers: bearer(reader),
    );
    expect((badBody.data!['error']! as Json)['code'], 'invalid_body');
  });

  test('T-0060-AC4 trivia.server_error answers 500 on every route', () async {
    final dio = jsonDio(_backend('trivia.server_error'));
    for (final c in await _calls()) {
      final response = await _send(dio, c);
      expect(response.statusCode, 500, reason: '${c.$1} ${c.$2}');
      expect(
        (response.data! as Json)['error'],
        containsPair('code', 'injected_failure'),
      );
    }
    // Whatever the auth: the routes need no bearer to fail.
    final bare = await call<Json>(dio, 'GET', '/v1/me/trivia/best');
    expect(bare.statusCode, 500);
  });

  test(
    'T-0060-AC4 the server_error set and scenario answer the same body',
    () async {
      final set = jsonDio(_backend('trivia.server_error'));
      for (final c in await _calls()) {
        final scenario = triviaBackend()..useScenario('trivia.server_error');
        final a = await _send(jsonDio(scenario), c);
        final b = await _send(set, c);
        expect(a.statusCode, 500, reason: '${c.$1} ${c.$2}');
        expect(b.statusCode, a.statusCode);
        expect(b.data, a.data, reason: '${c.$1} ${c.$2}');
      }
    },
  );

  test(
    'T-0060-AC4 the empty set and scenario answer the same bodies',
    () async {
      final a = jsonDio(triviaBackend()..useScenario('trivia.empty'));
      final b = jsonDio(_backend('trivia.empty'));
      for (final c in await _calls()) {
        final x = await _send(a, c);
        final y = await _send(b, c);
        expect(y.statusCode, x.statusCode, reason: '${c.$1} ${c.$2}');
        expect(y.data, x.data, reason: '${c.$1} ${c.$2}');
      }
    },
  );

  test('T-0060-AC4 the empty scenario is empty even after the default set '
      'was used, and switching it off restores the default', () async {
    final backend = triviaBackend();
    final dio = jsonDio(backend);
    final round = await fetchRound(dio);
    await play(dio, round, parseAnswers('C0x10'));
    expect((await bestOf(dio))['all'], 2625);
    backend.useScenario('trivia.empty');
    expect(await bestOf(dio), isEmpty);
    final empty = await call<Json>(
      dio,
      'GET',
      '/v1/trivia/rounds',
      query: {'category': 'all', 'difficulty': 'easy', 'seed': 42},
    );
    expect(empty.statusCode, 400);
    backend.useScenario(null);
    expect((await bestOf(dio))['all'], 2625);
    expect(await fetchRound(dio), round);
  });

  test('T-0060-AC4 trivia.slow answers normally after the extra delay, and a '
      'shorter receive timeout times out', () async {
    final backend = triviaBackend()..useScenario('trivia.slow');
    final dio = jsonDio(backend);
    final watch = Stopwatch()..start();
    final response = await call<Json>(
      dio,
      'GET',
      '/v1/trivia/categories',
    );
    watch.stop();
    expect(response.statusCode, 200);
    expect(watch.elapsed, greaterThanOrEqualTo(triviaSlowDelay));
    expect(backend.recentTraffic.last.duration, triviaSlowDelay);
    final impatient = jsonDio(backend);
    impatient.options.receiveTimeout = const Duration(milliseconds: 200);
    await expectLater(
      impatient.get<Json>('/v1/trivia/categories'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.receiveTimeout,
        ),
      ),
    );
    backend.useScenario(null);
    final fast = Stopwatch()..start();
    await dio.get<Json>('/v1/trivia/categories');
    expect(fast.elapsed, lessThan(triviaSlowDelay));
  });

  test('T-0060-AC4 the slow scenario covers all four routes, 2 s each', () {
    expect(triviaSlowDelay, const Duration(seconds: 2));
    final rules = const TriviaMockDomain().scenarios['trivia.slow']!.rules;
    expect([
      for (final r in rules) '${r.method} ${r.path}',
    ], triviaRouteManifest);
    for (final r in rules) {
      expect(r.kind, isA<SlowFailure>());
      expect((r.kind as SlowFailure).delay, triviaSlowDelay);
    }
  });
}
