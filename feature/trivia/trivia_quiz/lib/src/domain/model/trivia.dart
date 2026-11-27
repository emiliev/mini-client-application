import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mc_media/mc_media.dart';
import 'package:trivia_quiz/src/domain/model/comic_id.dart';

part 'trivia.freezed.dart';

// The quiz as this feature plays it. Domain models: no JSON, so a bare
// `@freezed` (R30 is about models with JSON); the wire shapes are in
// `trivia_dto.dart`. Pure Dart: the engine and the blocs read them (R15).

/// How hard a round is. The wire name is the enum's name.
enum TriviaDifficulty {
  easy,
  medium,
  hard;

  /// The difficulty named [wire], or null for any other text (a deep link
  /// can carry anything).
  static TriviaDifficulty? fromWire(String? wire) {
    for (final d in values) {
      if (d.name == wire) {
        return d;
      }
    }
    return null;
  }
}

/// A category a round can be drawn from (`all` draws from every one).
@freezed
abstract class TriviaCategory with _$TriviaCategory {
  const factory TriviaCategory({
    required String id,
    required String name,
    required int questionCount,
    required ApiImage image,
  }) = _TriviaCategory;
}

/// One answer option.
@freezed
abstract class TriviaChoice with _$TriviaChoice {
  const factory TriviaChoice({required String id, required String text}) =
      _TriviaChoice;
}

/// One question: four choices in the order they are shown, the correct one,
/// and the time a player has in milliseconds.
@freezed
abstract class TriviaQuestion with _$TriviaQuestion {
  const factory TriviaQuestion({
    required String id,
    required String prompt,
    required List<TriviaChoice> choices,
    required String correctChoiceId,
    required int limitMs,
    ApiImage? image,

    /// The comic the question is about, when it is about one.
    ComicId? comicId,
  }) = _TriviaQuestion;
}

/// A round of ten questions, in the order they are asked (the server scores
/// in this order).
@freezed
abstract class TriviaRound with _$TriviaRound {
  const factory TriviaRound({
    required String id,
    required String category,
    required TriviaDifficulty difficulty,
    required int seed,
    required List<TriviaQuestion> questions,
  }) = _TriviaRound;
}

/// What the server made of a submitted round: its score is authoritative.
@freezed
abstract class ServerResult with _$ServerResult {
  const factory ServerResult({
    required int score,
    required int correct,
    required int bestScore,
    required bool isNewBest,

    /// Each answer's points, in round order.
    required List<int> points,
  }) = _ServerResult;
}
