import 'package:trivia_quiz/src/domain/engine/scoring.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';

/// Where the round is.
enum RoundPhase {
  /// The current question waits for an answer; its countdown runs.
  asking,

  /// The current question is answered or timed out; its feedback shows
  /// until [TriviaEngine.next].
  revealed,

  /// Every question is answered.
  finished,
}

/// One answered question, as the engine judged it and as it is submitted.
final class AnsweredQuestion {
  const AnsweredQuestion({
    required this.questionId,
    required this.choiceId,
    required this.elapsedMs,
    required this.outcome,
    required this.points,
    required this.hint,
    required this.streak,
  });

  final String questionId;

  /// Null when no choice was made (the question timed out).
  final String? choiceId;
  final int elapsedMs;
  final AnswerOutcome outcome;
  final int points;

  /// Whether the 50/50 hint was used on this question.
  final bool hint;

  /// The run of correct answers after this one (0 after a miss).
  final int streak;
}

/// The rules of one round, in pure Dart: no Flutter, no timers, no clock
/// (ADR-0014). Time comes in as numbers: the play bloc measures how long a
/// question has been open and passes `elapsedMs`; the engine only judges.
///
/// - Questions are asked in round order; each is answered (or times out)
///   once, then [next] moves on.
/// - The score, the correct count and the streak follow `CONTRACT.md` to the
///   point, so the local score equals the server's ([scoring.dart]).
/// - The 50/50 hint can be used once per round, on a question that is being
///   asked. It hides two of the three wrong choices; which one stays is a
///   pure function of the round and the question ([hintKeeps]), so the same
///   round always hides the same choices.
final class TriviaEngine {
  TriviaEngine(this.round) {
    if (round.questions.isEmpty) {
      throw ArgumentError.value(round, 'round', 'A round needs questions');
    }
  }

  final TriviaRound round;

  final List<AnsweredQuestion> _answers = [];
  int _index = 0;
  int _streak = 0;
  RoundPhase _phase = RoundPhase.asking;
  String? _hintedQuestionId;
  Set<String> _hidden = const {};

  /// The current question's position, from 0.
  int get index => _index;

  int get total => round.questions.length;

  /// The question being asked or revealed (the last one once finished).
  TriviaQuestion get question => round.questions[_index];

  RoundPhase get phase => _phase;

  bool get isLast => _index == total - 1;

  /// The answers so far, in round order.
  List<AnsweredQuestion> get answers => List.unmodifiable(_answers);

  /// The answer of the current question, once it is revealed.
  AnsweredQuestion? get revealed =>
      _phase == RoundPhase.revealed ? _answers.last : null;

  int get score => _answers.fold(0, (sum, a) => sum + a.points);

  int get correct =>
      _answers.where((a) => a.outcome == AnswerOutcome.correct).length;

  /// The run of correct answers so far.
  int get streak => _streak;

  /// Whether the hint can still be used: once per round, while asking.
  bool get canUseHint =>
      _hintedQuestionId == null && _phase == RoundPhase.asking;

  /// The choices the hint hid on the current question (empty without it).
  Set<String> get hiddenChoices =>
      _hintedQuestionId == question.id ? _hidden : const {};

  /// Milliseconds left on the current question at [elapsedMs], never below 0.
  int remainingMs(int elapsedMs) {
    final left = question.limitMs - elapsedMs;
    return left < 0 ? 0 : left;
  }

  /// Answers the current question with [choiceId] at [elapsedMs]. At or
  /// after the limit it is a timeout, whatever the choice (the server's rule).
  AnsweredQuestion answer(String choiceId, {required int elapsedMs}) {
    _expectAsking();
    if (!question.choices.any((c) => c.id == choiceId)) {
      throw ArgumentError.value(choiceId, 'choiceId', 'Not a choice');
    }
    if (hiddenChoices.contains(choiceId)) {
      throw ArgumentError.value(choiceId, 'choiceId', 'Hidden by the hint');
    }
    return _resolve(choiceId, elapsedMs);
  }

  /// The current question's time ran out: no choice, at the limit.
  AnsweredQuestion timeOut() {
    _expectAsking();
    return _resolve(null, question.limitMs);
  }

  /// Uses the 50/50 hint on the current question and returns the two
  /// choices it hides. Throws when [canUseHint] is false.
  Set<String> useHint() {
    if (!canUseHint) {
      throw StateError('The hint is used, or no question is being asked');
    }
    final keep = hintKeeps(round.id, question);
    _hintedQuestionId = question.id;
    _hidden = {
      for (final c in question.choices)
        if (c.id != question.correctChoiceId && c.id != keep) c.id,
    };
    return _hidden;
  }

  /// Moves on from a revealed question: to the next one, or to [finished]
  /// after the last.
  void next() {
    if (_phase != RoundPhase.revealed) {
      throw StateError('Only a revealed question moves on (phase $_phase)');
    }
    if (isLast) {
      _phase = RoundPhase.finished;
      return;
    }
    _index++;
    _phase = RoundPhase.asking;
  }

  AnsweredQuestion _resolve(String? choiceId, int elapsedMs) {
    final q = question;
    final outcome = judge(q, choiceId, elapsedMs);
    _streak = outcome == AnswerOutcome.correct ? _streak + 1 : 0;
    final hint = _hintedQuestionId == q.id;
    final answered = AnsweredQuestion(
      questionId: q.id,
      choiceId: choiceId,
      elapsedMs: elapsedMs,
      outcome: outcome,
      points: pointsFor(
        outcome,
        elapsedMs: elapsedMs,
        limitMs: q.limitMs,
        streak: _streak,
        hint: hint,
      ),
      hint: hint,
      streak: _streak,
    );
    _answers.add(answered);
    _phase = RoundPhase.revealed;
    return answered;
  }

  void _expectAsking() {
    if (_phase != RoundPhase.asking) {
      throw StateError('No question is being asked (phase $_phase)');
    }
  }
}

/// The wrong choice the 50/50 hint keeps on [question] of round [roundId]:
/// the wrong choices in the order they are shown, picked by an FNV-1a hash
/// of `<roundId>/<questionId>`. Deterministic, and it does not give the
/// answer away by position (the kept wrong choice may be before or after
/// the correct one).
String hintKeeps(String roundId, TriviaQuestion question) {
  final wrong = [
    for (final c in question.choices)
      if (c.id != question.correctChoiceId) c.id,
  ];
  return wrong[_fnv1a32('$roundId/${question.id}') % wrong.length];
}

int _fnv1a32(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
