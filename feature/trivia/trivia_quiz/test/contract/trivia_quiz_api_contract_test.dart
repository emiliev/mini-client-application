// Contract tests are the one place a feature test reaches `src/` (R7): the
// DTOs and the mapper against what `mc_fixtures_editorial` serves. The
// engine is not tested here: it runs through the flow (R6).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:trivia_quiz/src/domain/engine/scoring.dart';
import 'package:trivia_quiz/src/domain/engine/trivia_engine.dart';
import 'package:trivia_quiz/src/domain/model/comic_id.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/domain/model/trivia_dto.dart';
import 'package:trivia_quiz/src/domain/model/trivia_mapper.dart';

final Dio _dio = MockBackend(
  domains: [const TriviaMockDomain(), const IdentityMockDomain()],
).createDio()..options.validateStatus = (_) => true;

Options _as(String userId) => Options(
  headers: {'Authorization': 'Bearer ${mintAccessToken(userId, 1)}'},
);

Future<Map<String, dynamic>> _get(
  String path, {
  Map<String, dynamic>? query,
  String? user,
}) async => (await _dio.get<Map<String, dynamic>>(
  path,
  queryParameters: query,
  options: user == null ? null : _as(user),
)).data!;

Future<Map<String, dynamic>> _round(String c, String d, int seed) => _get(
  'v1/trivia/rounds',
  query: {'category': c, 'difficulty': d, 'seed': seed},
);

/// Encodes JSON with sorted keys, as the backend does, so equal data is
/// equal text.
String _canonical(Object? json) => jsonEncode(_sorted(json));

Object? _sorted(Object? json) => switch (json) {
  final Map<String, dynamic> map => {
    for (final key in map.keys.toList()..sort()) key: _sorted(map[key]),
  },
  final List<dynamic> list => [for (final e in list) _sorted(e)],
  _ => json,
};

AnsweredQuestion _answered(
  String id,
  String? choice, {
  int elapsedMs = 0,
  bool hint = false,
}) => AnsweredQuestion(
  questionId: id,
  choiceId: choice,
  elapsedMs: elapsedMs,
  outcome: AnswerOutcome.correct,
  points: 0,
  hint: hint,
  streak: 0,
);

void main() {
  group('T-0064-AC7 every trivia route round-trips through its DTO', () {
    test('T-0064-AC7 categories', () async {
      final body = await _get('v1/trivia/categories');
      expect(
        _canonical(CategoriesDto.fromJson(body).toJson()),
        _canonical(body),
      );
    });

    for (final (c, d, seed) in [
      ('all', 'easy', 42),
      ('characters', 'medium', 1),
      ('comics', 'hard', 2147483647),
      ('creators', 'easy', 0),
    ]) {
      test('T-0064-AC7 the round $c/$d/$seed', () async {
        final body = await _round(c, d, seed);
        expect(_canonical(RoundDto.fromJson(body).toJson()), _canonical(body));
      });
    }

    test('T-0064-AC7 a result, with the hint in its breakdown, and the best '
        'scores', () async {
      final round = await _round('all', 'easy', 42);
      final questions = (round['questions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final request = resultRequest(round['roundId'] as String, [
        for (final (i, q) in questions.indexed)
          _answered(
            q['id'] as String,
            q['correctChoiceId'] as String,
            hint: i == 3,
          ),
      ]);
      final response = await _dio.post<Map<String, dynamic>>(
        'v1/me/trivia/results',
        data: request.toJson(),
        options: _as('u-101'),
      );
      expect(response.statusCode, 200, reason: '${response.data}');
      final body = response.data!;
      expect(_canonical(ResultDto.fromJson(body).toJson()), _canonical(body));
      expect(
        (body['breakdown'] as List<dynamic>)[3],
        containsPair('hint', true),
      );
      final best = await _get('v1/me/trivia/best', user: 'u-100');
      expect(_canonical(BestListDto.fromJson(best).toJson()), _canonical(best));
    });
  });

  group('T-0064-AC7 the mapper', () {
    test('T-0064-AC7 a round maps to the domain: limits in ms, images, comic '
        'ids, choices in shown order', () async {
      final body = await _round('all', 'easy', 42);
      final round = RoundDto.fromJson(body).toDomain();
      final served = (body['questions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(round.id, 'r-all-easy-42');
      expect(round.difficulty, TriviaDifficulty.easy);
      expect(round.seed, 42);
      expect(round.questions, hasLength(10));
      for (final (i, q) in round.questions.indexed) {
        expect(q.id, served[i]['id']);
        expect(q.limitMs, 20000);
        expect(q.correctChoiceId, served[i]['correctChoiceId']);
        expect(
          [for (final c in q.choices) c.id],
          [
            for (final c in (served[i]['choices'] as List<dynamic>)) c['id'],
          ],
        );
        expect(q.image?.path, served[i]['imageUrl']);
        expect(
          q.comicId,
          served[i]['comicId'] == null
              ? null
              : ComicId(served[i]['comicId'] as int),
        );
      }
      expect(round.questions.where((q) => q.comicId != null), isNotEmpty);
    });

    test('T-0064-AC7 a round of an unknown difficulty is malformed', () async {
      final body = await _round('all', 'hard', 42);
      body['difficulty'] = 'extreme';
      expect(
        () => RoundDto.fromJson(body).toDomain(),
        throwsA(isA<FormatException>()),
      );
      expect(TriviaDifficulty.fromWire('hard'), TriviaDifficulty.hard);
      expect(TriviaDifficulty.fromWire(null), isNull);
    });

    test('T-0064-AC7 the request sends every choiceId (null too), and hint '
        'only when used', () {
      final json = resultRequest('r-all-easy-42', [
        _answered('q-a', 'c1', elapsedMs: 4200),
        _answered('q-b', null, elapsedMs: 20000),
        _answered('q-c', 'c3', hint: true),
      ]).toJson();
      expect(json, {
        'roundId': 'r-all-easy-42',
        'answers': [
          {'questionId': 'q-a', 'choiceId': 'c1', 'elapsedMs': 4200},
          {'questionId': 'q-b', 'choiceId': null, 'elapsedMs': 20000},
          {'questionId': 'q-c', 'choiceId': 'c3', 'elapsedMs': 0, 'hint': true},
        ],
      });
    });

    test('T-0064-AC7 a result and the best scores map to the domain', () {
      final result = const ResultDto(
        roundId: 'r-all-easy-42',
        category: 'all',
        score: 475,
        correct: 3,
        bestScore: 870,
        isNewBest: false,
        breakdown: [
          BreakdownDto(questionId: 'a', outcome: 'correct', points: 150),
          BreakdownDto(questionId: 'b', outcome: 'wrong', points: 0),
          BreakdownDto(
            questionId: 'c',
            outcome: 'correct',
            points: 325,
            hint: true,
          ),
        ],
      ).toDomain();
      expect(result.score, 475);
      expect(result.correct, 3);
      expect(result.bestScore, 870);
      expect(result.isNewBest, isFalse);
      expect(result.points, [150, 0, 325]);
      expect(
        const BestListDto(
          best: [
            BestDto(category: 'all', bestScore: 870),
            BestDto(category: 'characters', bestScore: 1340),
          ],
        ).toDomain(),
        {'all': 870, 'characters': 1340},
      );
    });
  });
}
