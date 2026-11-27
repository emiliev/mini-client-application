/// An independent oracle for the scoring rules in `CONTRACT.md`.
///
/// It shares no code with the fixture and is written differently on purpose:
/// the time bonus is found by counting up instead of dividing, and the streak
/// is scored as runs of correct answers instead of a running counter. A
/// mutation of the fixture's bonus, streak or timeout boundary makes the two
/// disagree.
library;

/// One answer of a round: [kind] is `C` (the correct choice), `W` (a wrong
/// choice) or `N` (no choice), at [elapsedMs].
typedef Answer = ({String kind, int elapsedMs});

/// Parses `C0 W0x9` into ten answers (`xN` repeats the one before it).
List<Answer> parseAnswers(String spec) {
  final out = <Answer>[];
  for (final token in spec.split(' ')) {
    final match = RegExp(r'^([CWN])(\d+)(?:x(\d+))?$').firstMatch(token);
    if (match == null) {
      throw FormatException('bad answer token', token);
    }
    final answer = (
      kind: match.group(1)!,
      elapsedMs: int.parse(match.group(2)!),
    );
    out.addAll(List.filled(int.parse(match.group(3) ?? '1'), answer));
  }
  return out;
}

/// The score and the correct count of [answers], for a round whose questions
/// have [limitSeconds] seconds each.
({int score, int correct}) oracle(int limitSeconds, List<Answer> answers) {
  final limit = limitSeconds * 1000;
  // A correct answer inside the limit "counts"; everything else is a break.
  final counts = [
    for (final a in answers) a.kind == 'C' && a.elapsedMs < limit,
  ];
  var score = 0;
  var run = 0;
  var correct = 0;
  for (var i = 0; i < answers.length; i++) {
    if (!counts[i]) {
      run = 0;
      continue;
    }
    correct++;
    // How many whole 1/50ths of the limit are left: the largest b in 0..50
    // with b * limit <= 50 * remaining.
    final remaining = limit - answers[i].elapsedMs;
    var bonus = 0;
    while (bonus < 50 && (bonus + 1) * limit <= 50 * remaining) {
      bonus++;
    }
    // Position within the run of correct answers: 0 for the first.
    final position = run;
    run++;
    score += 100 + bonus;
    for (var step = 0; step < position; step++) {
      score += 25;
    }
  }
  return (score: score, correct: correct);
}
