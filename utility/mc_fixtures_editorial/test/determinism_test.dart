import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'support.dart';

const List<String> _categories = ['all', 'characters', 'comics', 'creators'];

Future<String> _roundText(
  MockBackend backend,
  String category,
  String difficulty,
  int seed,
) async {
  final response = await call<String>(
    plainDio(backend),
    'GET',
    '/v1/trivia/rounds',
    query: {'category': category, 'difficulty': difficulty, 'seed': seed},
  );
  expectStatus(response, 200);
  return response.data!;
}

void main() {
  group('T-0060-AC1 determinism', () {
    test('T-0060-AC1: seed 42 gives byte-identical bodies, on one backend '
        'and on a fresh one, for every category and difficulty', () async {
      final first = triviaBackend();
      final second = triviaBackend();
      for (final category in _categories) {
        for (final difficulty in difficulties) {
          final a = await _roundText(first, category, difficulty, 42);
          expect(await _roundText(first, category, difficulty, 42), a);
          expect(await _roundText(second, category, difficulty, 42), a);
        }
      }
    });

    test('T-0060-AC1: rounds for seeds 42 and 43 differ', () async {
      final backend = triviaBackend();
      for (final category in _categories) {
        for (final difficulty in difficulties) {
          expect(
            await _roundText(backend, category, difficulty, 42),
            isNot(await _roundText(backend, category, difficulty, 43)),
            reason: '$category $difficulty',
          );
        }
      }
    });

    test(
      'T-0060-AC1: the round seed changes the questions and the round id',
      () async {
        final dio = jsonDio(triviaBackend());
        final a = await fetchRound(dio, seed: 42);
        final b = await fetchRound(dio, seed: 43);
        final idsA = [for (final q in questionsOf(a)) q['id']];
        final idsB = [for (final q in questionsOf(b)) q['id']];
        expect(idsA, isNot(idsB));
        expect(a['roundId'], 'r-all-easy-42');
        expect(b['roundId'], 'r-all-easy-43');
      },
    );

    test('T-0060-AC1: a round has 10 questions of the asked category and '
        'difficulty, none twice, over 200 seeds', () async {
      final dio = jsonDio(triviaBackend());
      for (var seed = 0; seed < 200; seed++) {
        final category = _categories[seed % _categories.length];
        final difficulty = difficulties[seed % difficulties.length];
        final round = await fetchRound(
          dio,
          category: category,
          difficulty: difficulty,
          seed: seed,
        );
        final questions = questionsOf(round);
        expect(questions, hasLength(10));
        final ids = [for (final q in questions) q['id']! as String];
        expect(ids.toSet(), hasLength(10), reason: 'seed $seed');
        for (final q in questions) {
          expect(q['difficulty'], difficulty);
          if (category != 'all') {
            expect(q['category'], category);
          }
          expect(
            q['timeLimitSeconds'],
            const {'easy': 20, 'medium': 15, 'hard': 10}[difficulty],
          );
        }
      }
    });

    test('T-0060-AC1: a round of category all mixes the categories', () async {
      final dio = jsonDio(triviaBackend());
      final seen = <Object?>{};
      for (var seed = 0; seed < 20; seed++) {
        for (final q in questionsOf(await fetchRound(dio, seed: seed))) {
          seen.add(q['category']);
        }
      }
      expect(seen, {'characters', 'comics', 'creators'});
    });

    test('T-0060-AC1: every question has 4 distinct choices c1 to c4 and '
        'exactly one is correct', () async {
      final dio = jsonDio(triviaBackend());
      for (var seed = 0; seed < 100; seed++) {
        final round = await fetchRound(
          dio,
          category: _categories[seed % 4],
          difficulty: difficulties[seed % 3],
          seed: seed,
        );
        for (final q in questionsOf(round)) {
          final choices = choicesOf(q);
          expect(choices, hasLength(4));
          expect({for (final c in choices) c['id']}, {'c1', 'c2', 'c3', 'c4'});
          expect({for (final c in choices) c['text']}, hasLength(4));
          expect(
            choices.where((c) => c['id'] == q['correctChoiceId']),
            hasLength(1),
          );
        }
      }
    });

    test('T-0060-AC1: over 1000 seeded rounds each position of the correct '
        'choice is 20 to 30 percent', () async {
      final dio = jsonDio(triviaBackend());
      final positions = List.filled(4, 0);
      for (var seed = 0; seed < 1000; seed++) {
        final round = await fetchRound(
          dio,
          category: _categories[seed % 4],
          difficulty: difficulties[seed % 3],
          seed: seed,
        );
        for (final q in questionsOf(round)) {
          positions[choicesOf(q).indexWhere(
            (c) => c['id'] == q['correctChoiceId'],
          )]++;
        }
      }
      final total = positions.fold(0, (a, b) => a + b);
      expect(total, 10000);
      for (var p = 0; p < 4; p++) {
        final share = positions[p] / total;
        expect(share, inInclusiveRange(0.20, 0.30), reason: '$p: $positions');
      }
    });

    test('T-0060-AC1: the choice order follows the round seed (one question '
        'is shown in several orders)', () async {
      final dio = jsonDio(triviaBackend());
      final orders = <String, Set<String>>{};
      for (var seed = 0; seed < 300; seed++) {
        final round = await fetchRound(dio, seed: seed);
        for (final q in questionsOf(round)) {
          (orders[q['id']! as String] ??= {}).add(
            [for (final c in choicesOf(q)) c['id']].join(),
          );
        }
      }
      final shuffled = orders.values.where((o) => o.length >= 4).length;
      expect(shuffled, greaterThan(40));
    });

    test('T-0060-AC1: another backend seed has other questions but the same '
        'shape and ids', () async {
      final a = await fetchRound(jsonDio(triviaBackend()));
      final b = await fetchRound(jsonDio(triviaBackend(seed: 7)));
      expect(
        [for (final q in questionsOf(a)) q['id']],
        [for (final q in questionsOf(b)) q['id']],
      );
      expect(
        [for (final q in questionsOf(a)) q['prompt']],
        isNot([for (final q in questionsOf(b)) q['prompt']]),
      );
    });

    test('T-0060-AC1: the cached questions cannot be changed', () {
      final q = triviaQuestionBank(42).first;
      expect(
        () => q.choices.add(const TriviaChoice(id: 'c5', text: 'x')),
        throwsUnsupportedError,
      );
      expect(
        () => q.choices[0] = const TriviaChoice(id: 'c1', text: 'x'),
        throwsUnsupportedError,
      );
      expect(q.choices.clear, throwsUnsupportedError);
      expect(() => q.facts['kind'] = 'x', throwsUnsupportedError);
      expect(() => q.facts.remove('kind'), throwsUnsupportedError);
      expect(q.facts.clear, throwsUnsupportedError);
      for (final other in triviaQuestionBank(42)) {
        expect(() => other.choices.removeLast(), throwsUnsupportedError);
        expect(() => other.facts['x'] = 1, throwsUnsupportedError);
      }
    });

    test('T-0060-AC1: the bank holds at least 120 questions, 24 per template, '
        'with every (category, difficulty) pool at least 10 deep', () {
      for (final seed in [42, 7, 0]) {
        final bank = triviaQuestionBank(seed);
        expect(bank.length, greaterThanOrEqualTo(120));
        expect(bank.map((q) => q.id).toSet(), hasLength(bank.length));
        final templates = <String, int>{};
        for (final q in bank) {
          templates[q.template] = (templates[q.template] ?? 0) + 1;
        }
        expect(templates.values.toSet(), {24});
        for (final category in categoryIds) {
          for (final difficulty in difficulties) {
            expect(
              bank
                  .where(
                    (q) => q.category == category && q.difficulty == difficulty,
                  )
                  .length,
              greaterThanOrEqualTo(10),
              reason: '$category $difficulty',
            );
          }
        }
        // No two questions of a seed ask the same thing.
        expect(bank.map((q) => q.prompt).toSet(), hasLength(bank.length));
      }
    });
  });
}
