// Plain unit tests of the pure-Dart engine (allowed since ADR-0015), for
// what the flow cannot reach or reaches only slowly: the hint's choice of
// what to hide, and the engine's refusals. The scoring rules themselves are
// the BDD outline over CONTRACT.md's worked examples.
import 'package:mc_media/mc_media.dart';
import 'package:test/test.dart';
import 'package:trivia_quiz/src/domain/engine/scoring.dart';
import 'package:trivia_quiz/src/domain/engine/trivia_engine.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';

TriviaQuestion _question(String id, {String correct = 'c2'}) => TriviaQuestion(
  id: id,
  prompt: 'Prompt $id',
  choices: const [
    TriviaChoice(id: 'c1', text: 'one'),
    TriviaChoice(id: 'c2', text: 'two'),
    TriviaChoice(id: 'c3', text: 'three'),
    TriviaChoice(id: 'c4', text: 'four'),
  ],
  correctChoiceId: correct,
  limitMs: 10000,
  image: const ApiImage(path: 'mock-asset://characters/001'),
);

TriviaRound _round(int questions, {String id = 'r-all-hard-42'}) => TriviaRound(
  id: id,
  category: 'all',
  difficulty: TriviaDifficulty.hard,
  seed: 42,
  questions: [for (var i = 0; i < questions; i++) _question('q-$i')],
);

void main() {
  group('T-0064-AC6 the hint', () {
    test('T-0064-AC6 it keeps the correct choice and one wrong one, the same '
        'one every time, and that one depends on the round and question', () {
      final kept = <String>{};
      for (var r = 0; r < 40; r++) {
        for (final correct in ['c1', 'c2', 'c3', 'c4']) {
          final q = _question('q-$r', correct: correct);
          final keep = hintKeeps('r-all-easy-$r', q);
          expect(keep, isNot(correct));
          expect(keep, hintKeeps('r-all-easy-$r', q), reason: 'deterministic');
          kept.add(keep);
        }
      }
      expect(
        kept,
        hasLength(4),
        reason: 'any wrong choice may be the one kept',
      );
    });

    test('T-0064-AC6 the kept wrong choice is as often before the correct one '
        'as after it, so its position gives nothing away', () {
      var before = 0;
      var after = 0;
      for (var r = 0; r < 400; r++) {
        final keep = hintKeeps('r-all-easy-$r', _question('q-x'));
        keep.compareTo('c2') < 0 ? before++ : after++;
      }
      // c2 is correct: c1 is before it, c3 and c4 after (a third and two
      // thirds of uniform picks).
      expect(before, inInclusiveRange(90, 180));
      expect(after, inInclusiveRange(220, 310));
    });

    test('T-0064-AC6 it hides two wrong choices of the question asked, once '
        'per round; a hidden choice cannot be answered', () {
      final engine = TriviaEngine(_round(2));
      final hidden = engine.useHint();
      expect(hidden, hasLength(2));
      expect(hidden, isNot(contains('c2')));
      expect(
        hidden,
        isNot(contains(hintKeeps('r-all-hard-42', engine.question))),
      );
      expect(engine.hiddenChoices, hidden);
      expect(engine.canUseHint, isFalse);
      expect(() => engine.useHint(), throwsStateError);
      expect(
        () => engine.answer(hidden.first, elapsedMs: 0),
        throwsArgumentError,
      );
      final a = engine.answer('c2', elapsedMs: 0);
      expect(a.hint, isTrue);
      expect(a.points, basePoints + maxTimeBonus - hintPenalty);
      engine.next();
      expect(engine.hiddenChoices, isEmpty, reason: 'only on its question');
      expect(engine.canUseHint, isFalse, reason: 'once per round');
    });
  });

  group('T-0064-AC6 the round', () {
    test('T-0064-AC6 a timeout is no choice at the limit, resets the streak, '
        'and the round finishes after its last question', () {
      final engine = TriviaEngine(_round(3));
      expect(engine.answer('c2', elapsedMs: 0).streak, 1);
      engine.next();
      final t = engine.timeOut();
      expect(
        (t.choiceId, t.elapsedMs, t.outcome, t.points, t.streak),
        (
          null,
          10000,
          AnswerOutcome.timeout,
          0,
          0,
        ),
      );
      engine.next();
      expect(engine.isLast, isTrue);
      engine.answer('c1', elapsedMs: 9999);
      engine.next();
      expect(engine.phase, RoundPhase.finished);
      expect(engine.answers, hasLength(3));
      expect(engine.score, 150);
      expect(engine.correct, 1);
    });

    test('T-0064-AC6 the engine refuses what the round does not allow', () {
      expect(() => TriviaEngine(_round(0)), throwsArgumentError);
      final engine = TriviaEngine(_round(1));
      expect(() => engine.next(), throwsStateError, reason: 'not revealed');
      expect(
        () => engine.answer('c9', elapsedMs: 0),
        throwsArgumentError,
        reason: 'not a choice',
      );
      engine.answer('c2', elapsedMs: 0);
      expect(() => engine.answer('c2', elapsedMs: 0), throwsStateError);
      expect(() => engine.timeOut(), throwsStateError);
      expect(engine.remainingMs(12000), 0, reason: 'never below 0');
    });
  });
}
