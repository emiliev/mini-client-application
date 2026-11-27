import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';

import 'oracle.dart';
import 'support.dart';

/// The package directory in the test's runfiles (Bazel) or the checkout.
File _contract() {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null)
      '$srcDir/$workspace/utility/mc_fixtures_editorial/CONTRACT.md',
    'utility/mc_fixtures_editorial/CONTRACT.md',
    'CONTRACT.md',
  ]) {
    if (File(candidate).existsSync()) {
      return File(candidate);
    }
  }
  throw StateError('CONTRACT.md not found from ${Directory.current}');
}

typedef _Example = ({
  String id,
  String difficulty,
  String answers,
  int score,
  int correct,
});

/// The worked-example rows of CONTRACT.md (`| E1 | easy | `C0 W0x9` | ...`).
List<_Example> _examples() {
  final row = RegExp(
    r'^\| (E\d+) \| (\w+) \| `([^`]+)` \| (\d+) \| (\d+) \|',
    multiLine: true,
  );
  return [
    for (final m in row.allMatches(_contract().readAsStringSync()))
      (
        id: m.group(1)!,
        difficulty: m.group(2)!,
        answers: m.group(3)!,
        score: int.parse(m.group(4)!),
        correct: int.parse(m.group(5)!),
      ),
  ];
}

int _limitSeconds(String difficulty) =>
    timeLimitSecondsByDifficulty[difficulty]!;

void main() {
  group('T-0060-AC2 scoring: the worked examples of CONTRACT.md', () {
    final examples = _examples();

    test('T-0060-AC2: CONTRACT.md has at least 8 worked examples', () {
      expect(examples.length, greaterThanOrEqualTo(8));
      expect({for (final e in examples) e.id}, hasLength(examples.length));
    });

    for (final e in _examples()) {
      test('T-0060-AC2: ${e.id} ${e.difficulty} ${e.answers} scores '
          '${e.score} (${e.correct} correct)', () async {
        final dio = jsonDio(triviaBackend());
        final round = await fetchRound(dio, difficulty: e.difficulty);
        final spec = parseAnswers(e.answers);
        expect(spec, hasLength(roundSize));
        final result = await play(dio, round, spec);
        expect(result['score'], e.score);
        expect(result['correct'], e.correct);
        // The oracle reads the same table: the doc, the oracle and the
        // server all agree.
        final expected = oracle(_limitSeconds(e.difficulty), spec);
        expect(expected.score, e.score);
        expect(expected.correct, e.correct);
        final breakdown = (result['breakdown']! as List).cast<Json>();
        expect(breakdown, hasLength(roundSize));
        expect(
          breakdown.fold<int>(0, (sum, b) => sum + (b['points']! as int)),
          e.score,
        );
      });
    }
  });

  group('T-0060-AC2 scoring: boundaries and rules', () {
    for (final difficulty in difficulties) {
      final limit = _limitSeconds(difficulty) * 1000;
      for (final (elapsed, points, outcome) in [
        (0, 150, 'correct'),
        (limit - 1, 100, 'correct'),
        (limit, 0, 'timeout'),
        (limit + 1, 0, 'timeout'),
      ]) {
        test('T-0060-AC2: $difficulty correct at $elapsed ms (limit '
            '$limit) is $outcome, $points points', () async {
          final dio = jsonDio(triviaBackend());
          final round = await fetchRound(dio, difficulty: difficulty);
          final result = await play(dio, round, [
            (kind: 'C', elapsedMs: elapsed),
            ...List.filled(9, (kind: 'W', elapsedMs: 0)),
          ]);
          expect(result['score'], points);
          final first = (result['breakdown']! as List).first as Json;
          expect(first['outcome'], outcome);
          expect(first['points'], points);
        });
      }

      test('T-0060-AC2: $difficulty a wrong answer at the limit is a '
          'timeout and one just inside is wrong', () async {
        final dio = jsonDio(triviaBackend());
        final round = await fetchRound(dio, difficulty: difficulty);
        final result = await play(dio, round, [
          (kind: 'W', elapsedMs: limit - 1),
          (kind: 'W', elapsedMs: limit),
          (kind: 'N', elapsedMs: 0),
          ...List.filled(7, (kind: 'C', elapsedMs: 0)),
        ]);
        final outcomes = [
          for (final b in (result['breakdown']! as List).cast<Json>())
            b['outcome'],
        ];
        expect(outcomes.take(3), ['wrong', 'timeout', 'timeout']);
        // The streak restarted after the three misses: 150 + 175 + ...
        expect(result['score'], 150 + 175 + 200 + 225 + 250 + 275 + 300);
        expect(result['correct'], 7);
      });
    }

    test('T-0060-AC2: the time bonus floors, at every step of a medium '
        'round', () async {
      final dio = jsonDio(triviaBackend());
      final round = await fetchRound(dio, difficulty: 'medium');
      for (final elapsed in [1, 299, 300, 301, 7499, 7500, 7501, 14699]) {
        final spec = [
          (kind: 'C', elapsedMs: elapsed),
          ...List.filled(9, (kind: 'W', elapsedMs: 0)),
        ];
        final result = await play(dio, round, spec);
        expect(
          result['score'],
          oracle(15, spec).score,
          reason: 'elapsed $elapsed',
        );
      }
    });

    test('T-0060-AC2: the order of the answers array does not matter; the '
        'streak follows the round order', () async {
      final dio = jsonDio(triviaBackend());
      final round = await fetchRound(dio);
      final spec = parseAnswers('C0 C100 W0 C200 C300 C400 N0 C500 C0 C0');
      final answers = answersFor(round, spec);
      final inOrder = await postResult(dio, {
        'roundId': round['roundId'],
        'answers': answers,
      });
      final reversed = await postResult(dio, {
        'roundId': round['roundId'],
        'answers': answers.reversed.toList(),
      });
      expect(reversed.data!['score'], inOrder.data!['score']);
      expect(inOrder.data!['score'], oracle(20, spec).score);
      expect(
        [
          for (final b in (reversed.data!['breakdown']! as List).cast<Json>())
            b['questionId'],
        ],
        [for (final q in questionsOf(round)) q['id']],
      );
    });

    test('T-0060-AC2: a claimed score in the request is never read', () async {
      final dio = jsonDio(triviaBackend());
      final round = await fetchRound(dio);
      final response = await postResult(dio, {
        'roundId': round['roundId'],
        'score': 99999,
        'correct': 10,
        'bestScore': 99999,
        'answers': answersFor(round, parseAnswers('W0x10')),
      });
      expect(response.data!['score'], 0);
      expect(response.data!['correct'], 0);
    });

    test('T-0060-AC2: the constants of the rules are 100, 50 and 25', () {
      expect(basePoints, 100);
      expect(maxTimeBonus, 50);
      expect(streakStep, 25);
    });

    test('T-0060-AC2: the same answers on every category and difficulty '
        'score the same', () async {
      final dio = jsonDio(triviaBackend());
      for (final category in ['all', ...categoryIds]) {
        final round = await fetchRound(
          dio,
          category: category,
          difficulty: 'hard',
        );
        final spec = parseAnswers('C100 C200 C300 W0 C400 N0 C500 C600 W0 C0');
        final result = await play(dio, round, spec, user: collector);
        expect(result['score'], oracle(10, spec).score, reason: category);
        expect(result['category'], category);
      }
    });
  });

  group('T-0060-AC2 scoring: the oracle against the server', () {
    test('T-0060-AC2: 50 seeded rounds with random answers and timings give '
        'the oracle\'s score and correct count', () async {
      final dio = jsonDio(triviaBackend());
      final random = Random(2026);
      final seenOutcomes = <Object?>{};
      var longestRun = 0;
      var boundaryHits = 0;
      for (var round = 0; round < 50; round++) {
        final difficulty = difficulties[round % 3];
        final limit = _limitSeconds(difficulty) * 1000;
        final data = await fetchRound(
          dio,
          category: ['all', ...categoryIds][round % 4],
          difficulty: difficulty,
          seed: 1000 + round,
        );
        final spec = <Answer>[];
        var run = 0;
        for (var i = 0; i < roundSize; i++) {
          final kind = switch (random.nextInt(10)) {
            < 6 => 'C',
            < 9 => 'W',
            _ => 'N',
          };
          final elapsed = switch (random.nextInt(8)) {
            0 => limit - 1,
            1 => limit,
            2 => limit + 1,
            3 => 0,
            _ => random.nextInt(limit + 2000),
          };
          if (elapsed >= limit - 1 && elapsed <= limit + 1) {
            boundaryHits++;
          }
          spec.add((kind: kind, elapsedMs: elapsed));
          run = kind == 'C' && elapsed < limit ? run + 1 : 0;
          longestRun = max(longestRun, run);
        }
        final result = await play(dio, data, spec);
        final expected = oracle(_limitSeconds(difficulty), spec);
        expect(result['score'], expected.score, reason: 'round $round $spec');
        expect(result['correct'], expected.correct, reason: 'round $round');
        for (final b in (result['breakdown']! as List).cast<Json>()) {
          seenOutcomes.add(b['outcome']);
        }
      }
      // The sample is not vacuous.
      expect(seenOutcomes, {'correct', 'wrong', 'timeout'});
      expect(longestRun, greaterThanOrEqualTo(4));
      expect(boundaryHits, greaterThan(40));
    });

    test('T-0060-AC2: the oracle itself matches hand-computed values', () {
      expect(oracle(20, parseAnswers('C0x10')).score, 2625);
      expect(oracle(20, parseAnswers('C5000 W0x9')).score, 137);
      expect(oracle(10, parseAnswers('C3333 W0x9')).score, 133);
      expect(oracle(15, parseAnswers('C14999x10')).score, 2125);
      expect(oracle(20, parseAnswers('C20000 W0x9')).score, 0);
      expect(parseAnswers('C0 W5x2'), [
        (kind: 'C', elapsedMs: 0),
        (kind: 'W', elapsedMs: 5),
        (kind: 'W', elapsedMs: 5),
      ]);
      expect(() => parseAnswers('X1'), throwsFormatException);
    });
  });
}
