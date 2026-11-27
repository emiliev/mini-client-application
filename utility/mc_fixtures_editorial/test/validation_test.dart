import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';

import 'oracle.dart';
import 'support.dart';

void _expectError(
  Response<Json> response,
  int status,
  String code, {
  String? parameter,
}) {
  expect(response.statusCode, status, reason: '${response.data}');
  final error = response.data!['error']! as Json;
  expect(error['code'], code);
  expect(error['message'], isA<String>());
  if (parameter != null) {
    expect(error['parameter'], parameter);
  }
}

Future<Response<Json>> _rounds(Dio dio, Map<String, Object?> query) =>
    call<Json>(dio, 'GET', '/v1/trivia/rounds', query: query);

const Map<String, Object?> _ok = {
  'category': 'all',
  'difficulty': 'easy',
  'seed': '42',
};

Map<String, Object?> _with(String key, Object? value) {
  final query = {..._ok};
  if (value == null) {
    query.remove(key);
  } else {
    query[key] = value;
  }
  return query;
}

void main() {
  group('T-0060-AC3 validation of GET rounds', () {
    late Dio dio;
    setUp(() => dio = jsonDio(triviaBackend()));

    for (final bad in <Object?>[
      null,
      '',
      'nope',
      'ALL',
      'All',
      'comic',
      ' all',
    ]) {
      test('T-0060-AC3: category ${bad == null ? 'missing' : '"$bad"'} is '
          'unknown_category', () async {
        _expectError(
          await _rounds(dio, _with('category', bad)),
          400,
          'unknown_category',
          parameter: 'category',
        );
      });
    }

    for (final bad in <Object?>[null, '', 'Easy', 'extreme', 'all', 'EASY']) {
      test('T-0060-AC3: difficulty ${bad == null ? 'missing' : '"$bad"'} is '
          'invalid_difficulty', () async {
        _expectError(
          await _rounds(dio, _with('difficulty', bad)),
          400,
          'invalid_difficulty',
          parameter: 'difficulty',
        );
      });
    }

    for (final bad in <Object?>[
      null,
      '',
      '-1',
      '+5',
      '4.5',
      'abc',
      '007',
      ' 5',
      '5 ',
      '0x10',
      '2147483648',
      '99999999999999999999',
      '1e3',
    ]) {
      test('T-0060-AC3: seed ${bad == null ? 'missing' : '"$bad"'} is '
          'invalid_seed', () async {
        _expectError(
          await _rounds(dio, _with('seed', bad)),
          400,
          'invalid_seed',
          parameter: 'seed',
        );
      });
    }

    for (final good in ['0', '1', '42', '2147483647']) {
      test('T-0060-AC3: seed $good is accepted', () async {
        final response = await _rounds(dio, _with('seed', good));
        expect(response.statusCode, 200);
        expect(response.data!['seed'], int.parse(good));
        expect(response.data!['roundId'], 'r-all-easy-$good');
      });
    }

    test('T-0060-AC3: the checks run in the order category, difficulty, '
        'seed', () async {
      final allBad = {'category': 'x', 'difficulty': 'x', 'seed': 'x'};
      _expectError(await _rounds(dio, allBad), 400, 'unknown_category');
      _expectError(
        await _rounds(dio, {...allBad, 'category': 'all'}),
        400,
        'invalid_difficulty',
      );
      _expectError(
        await _rounds(dio, {
          ...allBad,
          'category': 'all',
          'difficulty': 'hard',
        }),
        400,
        'invalid_seed',
      );
    });

    test(
      'T-0060-AC3: the unknown_category message lists the categories',
      () async {
        final response = await _rounds(dio, _with('category', 'nope'));
        expect(
          (response.data!['error']! as Json)['message'],
          'category must be one of all, characters, comics, creators',
        );
      },
    );

    test('T-0060-AC3: a rejected request is a 400 with no questions', () async {
      final response = await _rounds(dio, _with('seed', '-1'));
      expect(response.data!.keys, ['error']);
    });

    test(
      'T-0060-AC3: the rounds and categories routes need no bearer',
      () async {
        expect((await _rounds(dio, _ok)).statusCode, 200);
        expect(
          (await call<Json>(dio, 'GET', '/v1/trivia/categories')).statusCode,
          200,
        );
      },
    );
  });

  group('T-0060-AC3 auth', () {
    final routes = <(String, String, Object?)>[
      (
        'POST',
        '/v1/me/trivia/results',
        {'roundId': 'r-all-easy-42', 'answers': <Object?>[]},
      ),
      ('GET', '/v1/me/trivia/best', null),
    ];
    final headers = <String, Map<String, String>>{
      'no bearer': {},
      'expired token': {
        'Authorization': 'Bearer ${expiredAccessToken(reader)}',
      },
      'refresh token': {
        'Authorization': 'Bearer ${mintRefreshToken(reader, 1)}',
      },
      'garbage': {'Authorization': 'Bearer nope'},
      'unknown user': {
        'Authorization': 'Bearer ${mintAccessToken('u-999', 1)}',
      },
      'wrong scheme': {
        'Authorization': 'Basic ${mintAccessToken(reader, 1)}',
      },
      'empty bearer': {'Authorization': 'Bearer '},
    };
    for (final MapEntry(key: label, value: header) in headers.entries) {
      for (final (method, path, body) in routes) {
        test('T-0060-AC3: $method $path with $label is 401', () async {
          final dio = jsonDio(triviaBackend());
          final response = await call<Json>(
            dio,
            method,
            path,
            body: body,
            headers: header,
          );
          _expectError(response, 401, 'unauthenticated');
        });
      }
    }

    test('T-0060-AC3: auth is checked before the body', () async {
      final response = await call<Json>(
        jsonDio(triviaBackend()),
        'POST',
        '/v1/me/trivia/results',
        body: 'not an object',
      );
      _expectError(response, 401, 'unauthenticated');
    });

    test('T-0060-AC3: a 401 stores nothing', () async {
      final dio = jsonDio(triviaBackend());
      final round = await fetchRound(dio);
      final response = await call<Json>(
        dio,
        'POST',
        '/v1/me/trivia/results',
        body: {
          'roundId': round['roundId'],
          'answers': answersFor(round, parseAnswers('C0x10')),
        },
        headers: {'Authorization': 'Bearer ${expiredAccessToken(reader)}'},
      );
      expect(response.statusCode, 401);
      expect(await bestOf(dio), seededBest[reader]);
    });
  });

  group('T-0060-AC3 validation of POST results', () {
    late Dio dio;
    late Json round;
    late List<Json> answers;
    setUp(() async {
      dio = jsonDio(triviaBackend());
      round = await fetchRound(dio);
      answers = answersFor(round, parseAnswers('C0x10'));
    });

    Future<Response<Json>> post(Object? body) => postResult(dio, body);

    for (final (label, body) in <(String, Object?)>[
      ('a list', <Object?>[]),
      ('a string', 'x'),
      ('no body', null),
      ('no roundId', {'answers': <Object?>[]}),
      ('a numeric roundId', {'roundId': 5, 'answers': <Object?>[]}),
      ('no answers', {'roundId': 'r-all-easy-42'}),
      ('answers not a list', {'roundId': 'r-all-easy-42', 'answers': 'x'}),
      (
        'an answer that is not an object',
        {
          'roundId': 'r-all-easy-42',
          'answers': ['x'],
        },
      ),
      (
        'an answer with no questionId',
        {
          'roundId': 'r-all-easy-42',
          'answers': [
            {'choiceId': 'c1', 'elapsedMs': 1},
          ],
        },
      ),
      (
        'an answer with no choiceId key',
        {
          'roundId': 'r-all-easy-42',
          'answers': [
            {'questionId': 'q', 'elapsedMs': 1},
          ],
        },
      ),
      (
        'a choiceID key of the wrong case',
        {
          'roundId': 'r-all-easy-42',
          'answers': [
            {'questionId': 'q', 'choiceID': 'c1', 'elapsedMs': 1},
          ],
        },
      ),
      (
        'a numeric choiceId',
        {
          'roundId': 'r-all-easy-42',
          'answers': [
            {'questionId': 'q', 'choiceId': 1, 'elapsedMs': 1},
          ],
        },
      ),
    ]) {
      test('T-0060-AC3: $label is invalid_body', () async {
        _expectError(
          await post(body),
          400,
          'invalid_body',
          parameter: 'body',
        );
      });
    }

    for (final id in [
      'nope',
      '',
      'r-all-easy',
      'r-all-easy-',
      'r-nothing-easy-42',
      'r-all-extreme-42',
      'r-all-easy-007',
      'r-all-easy--1',
      'r-all-easy-2147483648',
      'r-all-easy-42 ',
      ' r-all-easy-42',
      'R-all-easy-42',
      'r-all-easy-42-extra',
    ]) {
      test('T-0060-AC3: roundId "$id" is unknown_round', () async {
        _expectError(
          await post({'roundId': id, 'answers': answers}),
          400,
          'unknown_round',
          parameter: 'roundId',
        );
      });
    }

    test(
      'T-0060-AC3: a round that was never requested can be scored',
      () async {
        final other = await fetchRound(dio, category: 'comics', seed: 9);
        final response = await post({
          'roundId': 'r-comics-easy-9',
          'answers': answersFor(other, parseAnswers('C0x10')),
        });
        expect(response.statusCode, 200);
        final unseen = await post({
          'roundId': 'r-creators-hard-31337',
          'answers': answersFor(
            await fetchRound(
              jsonDio(triviaBackend()),
              category: 'creators',
              difficulty: 'hard',
              seed: 31337,
            ),
            parseAnswers('W0x10'),
          ),
        });
        expect(unseen.statusCode, 200);
      },
    );

    for (final count in [0, 1, 9, 11, 20]) {
      test('T-0060-AC3: $count answers is answer_count_mismatch', () async {
        final list = [for (var i = 0; i < count; i++) answers[i % 10]];
        final response = await post({
          'roundId': round['roundId'],
          'answers': list,
        });
        _expectError(
          response,
          400,
          'answer_count_mismatch',
          parameter: 'answers',
        );
        expect((response.data!['error']! as Json)['expected'], 10);
      });
    }

    test('T-0060-AC3: a question that is not in the round is '
        'unknown_question', () async {
      final bad = [...answers];
      bad[3] = {...bad[3], 'questionId': 'q-nothing-01'};
      final response = await post({
        'roundId': round['roundId'],
        'answers': bad,
      });
      _expectError(response, 400, 'unknown_question', parameter: 'answers');
      expect((response.data!['error']! as Json)['questionId'], 'q-nothing-01');
    });

    test(
      'T-0060-AC3: a question of another round is unknown_question',
      () async {
        final other = await fetchRound(dio, seed: 43);
        final foreign = questionsOf(other)
            .map((q) => q['id'])
            .firstWhere((id) => !questionsOf(round).any((q) => q['id'] == id));
        final bad = [...answers];
        bad[0] = {...bad[0], 'questionId': foreign};
        _expectError(
          await post({'roundId': round['roundId'], 'answers': bad}),
          400,
          'unknown_question',
        );
      },
    );

    test(
      'T-0060-AC3: answering a question twice is duplicate_answer',
      () async {
        final bad = [...answers];
        bad[5] = {...bad[0]};
        final response = await post({
          'roundId': round['roundId'],
          'answers': bad,
        });
        _expectError(response, 400, 'duplicate_answer', parameter: 'answers');
        expect(
          (response.data!['error']! as Json)['questionId'],
          answers[0]['questionId'],
        );
      },
    );

    test('T-0060-AC3: a choice that is not one of the question\'s is '
        'unknown_choice', () async {
      for (final choice in ['c5', 'c0', 'C1', '', 'x']) {
        final bad = [...answers];
        bad[2] = {...bad[2], 'choiceId': choice};
        final response = await post({
          'roundId': round['roundId'],
          'answers': bad,
        });
        _expectError(response, 400, 'unknown_choice', parameter: 'answers');
        expect((response.data!['error']! as Json)['choiceId'], choice);
      }
    });

    for (final (label, elapsed) in <(String, Object?)>[
      ('negative', -1),
      ('very negative', -100000),
      ('a decimal', 1.5),
      ('a string', '100'),
      ('null', null),
      ('a boolean', true),
    ]) {
      test('T-0060-AC3: elapsedMs $label is invalid_elapsed', () async {
        final bad = [...answers];
        bad[4] = {...bad[4], 'elapsedMs': elapsed};
        final response = await post({
          'roundId': round['roundId'],
          'answers': bad,
        });
        _expectError(response, 400, 'invalid_elapsed', parameter: 'answers');
        expect(
          (response.data!['error']! as Json)['questionId'],
          answers[4]['questionId'],
        );
      });
    }

    test(
      'T-0060-AC3: elapsedMs is checked for an unanswered question too',
      () async {
        final bad = [...answers];
        bad[1] = {
          'questionId': bad[1]['questionId'],
          'choiceId': null,
          'elapsedMs': -5,
        };
        _expectError(
          await post({'roundId': round['roundId'], 'answers': bad}),
          400,
          'invalid_elapsed',
        );
      },
    );

    test('T-0060-AC3: elapsedMs 0 and a huge value are accepted', () async {
      final spec = [
        (kind: 'C', elapsedMs: 0),
        (kind: 'W', elapsedMs: 1 << 40),
        ...List.filled(8, (kind: 'N', elapsedMs: 3600000)),
      ];
      expect(
        (await postResult(dio, {
          'roundId': round['roundId'],
          'answers': answersFor(round, spec),
        })).statusCode,
        200,
      );
    });

    test('T-0060-AC3: the checks run in order: body, round, count, question, '
        'duplicate, choice, elapsed', () async {
      final both = [...answers];
      // Each step adds one more fault; the earlier one wins.
      both[0] = {...both[0], 'elapsedMs': -1};
      _expectError(
        await post({'roundId': round['roundId'], 'answers': both}),
        400,
        'invalid_elapsed',
      );
      both[1] = {...both[1], 'choiceId': 'c9'};
      _expectError(
        await post({'roundId': round['roundId'], 'answers': both}),
        400,
        'unknown_choice',
      );
      both[2] = {...both[0], 'questionId': both[0]['questionId']};
      _expectError(
        await post({'roundId': round['roundId'], 'answers': both}),
        400,
        'duplicate_answer',
      );
      both[3] = {...both[3], 'questionId': 'q-nothing-01'};
      _expectError(
        await post({'roundId': round['roundId'], 'answers': both}),
        400,
        'unknown_question',
      );
      _expectError(
        await post({
          'roundId': round['roundId'],
          'answers': both.take(9).toList(),
        }),
        400,
        'answer_count_mismatch',
      );
      _expectError(
        await post({'roundId': 'nope', 'answers': both.take(9).toList()}),
        400,
        'unknown_round',
      );
      _expectError(
        await post({'roundId': 5, 'answers': both}),
        400,
        'invalid_body',
      );
    });

    test('T-0060-AC3: a rejected result changes nothing', () async {
      final before = await bestOf(dio);
      final bad = [...answers];
      bad[9] = {...bad[9], 'elapsedMs': -1};
      await post({'roundId': round['roundId'], 'answers': bad});
      expect(await bestOf(dio), before);
    });
  });

  group('T-0060-AC3 results are per user and persist until reset', () {
    late Dio dio;
    late Json round;
    setUp(() async {
      dio = jsonDio(triviaBackend());
      round = await fetchRound(dio, category: 'comics');
    });

    test('T-0060-AC3: the default set starts u-100 with two bests and '
        'u-101 with none', () async {
      expect(await bestOf(dio), {'all': 870, 'characters': 1340});
      expect(await bestOf(dio, user: collector), isEmpty);
    });

    test(
      'T-0060-AC3: one user\'s results are never visible to another',
      () async {
        await play(dio, round, parseAnswers('C0x10'), user: reader);
        expect(await bestOf(dio, user: collector), isEmpty);
        await play(dio, round, parseAnswers('C0 W0x9'), user: collector);
        expect(await bestOf(dio, user: collector), {'comics': 150});
        expect(await bestOf(dio), {
          'all': 870,
          'characters': 1340,
          'comics': 2625,
        });
      },
    );

    test('T-0060-AC3: bests persist across requests and clients until '
        'reset', () async {
      final backend = triviaBackend();
      final one = jsonDio(backend);
      await play(one, round, parseAnswers('C0x10'));
      expect((await bestOf(jsonDio(backend)))['comics'], 2625);
      backend.reset();
      expect(await bestOf(jsonDio(backend)), {'all': 870, 'characters': 1340});
    });

    test(
      'T-0060-AC3: isNewBest is true only on a strictly higher score',
      () async {
        Future<Json> score(String spec) =>
            play(dio, round, parseAnswers(spec), user: collector);
        var r = await score('C0 W0x9'); // 150: the first result
        expect([r['score'], r['bestScore'], r['isNewBest']], [150, 150, true]);
        r = await score('C0 W0x9'); // equal
        expect([r['score'], r['bestScore'], r['isNewBest']], [150, 150, false]);
        r = await score('C5000 W0x9'); // 137, lower
        expect([r['score'], r['bestScore'], r['isNewBest']], [137, 150, false]);
        r = await score('C0 C0 W0x8'); // 325, higher
        expect([r['score'], r['bestScore'], r['isNewBest']], [325, 325, true]);
        r = await score('C0 W0x9'); // lower again
        expect([r['score'], r['bestScore'], r['isNewBest']], [150, 325, false]);
        expect(await bestOf(dio, user: collector), {'comics': 325});
        r = await score('C0 C0 W0x8'); // 325 again: a tie
        expect([r['score'], r['bestScore'], r['isNewBest']], [325, 325, false]);
        r = await score('C0x10'); // the maximum
        expect(
          [r['score'], r['bestScore'], r['isNewBest']],
          [2625, 2625, true],
        );
        r = await score('C0x10');
        expect(
          [r['score'], r['bestScore'], r['isNewBest']],
          [2625, 2625, false],
        );
      },
    );

    test(
      'T-0060-AC3: a first result of 0 is not a new best but is listed',
      () async {
        final r = await play(
          dio,
          round,
          parseAnswers('W0x10'),
          user: collector,
        );
        expect([r['score'], r['bestScore'], r['isNewBest']], [0, 0, false]);
        expect(await bestOf(dio, user: collector), {'comics': 0});
        final better = await play(
          dio,
          round,
          parseAnswers('C0 W0x9'),
          user: collector,
        );
        expect(better['isNewBest'], isTrue);
      },
    );

    test(
      'T-0060-AC3: against a seeded best, only a higher score is new',
      () async {
        final all = await fetchRound(dio, difficulty: 'hard');
        // The seeded `all` best is 870.
        var r = await play(dio, all, parseAnswers('C0 C0 C0 C0 W0x6'));
        expect(
          [r['score'], r['bestScore'], r['isNewBest']],
          [
            oracle(10, parseAnswers('C0 C0 C0 C0 W0x6')).score,
            870,
            false,
          ],
        );
        r = await play(dio, all, parseAnswers('C0x6 W0x4'));
        final score = oracle(10, parseAnswers('C0x6 W0x4')).score;
        expect(score, 1275);
        expect([r['bestScore'], r['isNewBest']], [1275, true]);
      },
    );

    test('T-0060-AC3: the best is per category and shared by the '
        'difficulties of a category', () async {
      final easy = await fetchRound(dio, category: 'creators');
      final hard = await fetchRound(
        dio,
        category: 'creators',
        difficulty: 'hard',
      );
      await play(dio, easy, parseAnswers('C0 W0x9'), user: collector);
      final r = await play(dio, hard, parseAnswers('C0 W0x9'), user: collector);
      // Same score of 150 in the same category: not a new best.
      expect(r['isNewBest'], isFalse);
      expect(await bestOf(dio, user: collector), {'creators': 150});
      await play(dio, round, parseAnswers('C0 W0x9'), user: collector);
      expect(await bestOf(dio, user: collector), {
        'comics': 150,
        'creators': 150,
      });
    });

    test('T-0060-AC3: the best list is sorted by category', () async {
      for (final category in ['creators', 'comics', 'characters']) {
        final r = await fetchRound(dio, category: category);
        await play(dio, r, parseAnswers('C0 W0x9'), user: collector);
      }
      final response = await call<Json>(
        dio,
        'GET',
        '/v1/me/trivia/best',
        headers: bearer(collector),
      );
      expect(
        [
          for (final e in (response.data!['best']! as List).cast<Json>())
            e['category'],
        ],
        ['characters', 'comics', 'creators'],
      );
    });
  });
}
