import 'package:mc_fixtures_editorial/src/data/bank.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

/// Questions per round.
const int roundSize = 10;

/// The largest accepted round seed (2^31 - 1).
const int maxRoundSeed = 2147483647;

final RegExp _canonicalInt = RegExp(r'^(0|[1-9][0-9]*)$');

/// A round seed from a query value: a canonical decimal integer in
/// `0..maxRoundSeed` (no sign, no padding, no leading zeros), else null.
int? parseRoundSeed(String? raw) {
  if (raw == null || !_canonicalInt.hasMatch(raw)) {
    return null;
  }
  final value = int.tryParse(raw);
  return value == null || value > maxRoundSeed ? null : value;
}

/// What identifies a round: the same three values always give the same round.
final class RoundSpec {
  const RoundSpec(this.category, this.difficulty, this.seed);

  final String category;
  final String difficulty;
  final int seed;

  /// `r-<category>-<difficulty>-<seed>`. The server keeps no round state: the
  /// id names the round, which is rebuilt from it.
  String get roundId => 'r-$category-$difficulty-$seed';
}

final RegExp _roundIdPattern = RegExp(
  r'^r-([a-z]+)-(easy|medium|hard)-(0|[1-9][0-9]*)$',
);

/// The round [roundId] names, or null when it is not a round id of one of
/// [categories].
RoundSpec? parseRoundId(String roundId, Iterable<String> categories) {
  final match = _roundIdPattern.firstMatch(roundId);
  if (match == null) {
    return null;
  }
  final seed = parseRoundSeed(match.group(3));
  if (seed == null || !categories.contains(match.group(1))) {
    return null;
  }
  return RoundSpec(match.group(1)!, match.group(2)!, seed);
}

/// The questions of [spec]'s round: [roundSize] distinct ones from [bank],
/// each with its choices shuffled. Question and choice order depend only on
/// the spec and the bank.
List<TriviaQuestion> buildRound(List<TriviaQuestion> bank, RoundSpec spec) {
  final pool = [
    for (final q in bank)
      if ((spec.category == allCategory || q.category == spec.category) &&
          q.difficulty == spec.difficulty)
        q,
  ];
  final rng = SplitMix64(
    spec.seed,
  ).fork('round').fork(spec.category).fork(spec.difficulty);
  final picker = rng.fork('questions');
  // A partial Fisher-Yates: the first [roundSize] slots are the round.
  for (var i = 0; i < roundSize; i++) {
    final j = i + picker.nextInt(pool.length - i);
    final held = pool[i];
    pool[i] = pool[j];
    pool[j] = held;
  }
  return [
    for (final q in pool.take(roundSize))
      q.withChoices(_shuffleChoices(q, rng.fork('choices').fork(q.id))),
  ];
}

List<TriviaChoice> _shuffleChoices(TriviaQuestion q, SplitMix64 rng) {
  final list = [...q.choices];
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final held = list[i];
    list[i] = list[j];
    list[j] = held;
  }
  return list;
}
