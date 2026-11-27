import 'package:mc_media/mc_media.dart';
import 'package:trivia_quiz/src/domain/engine/trivia_engine.dart';
import 'package:trivia_quiz/src/domain/model/comic_id.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/domain/model/trivia_dto.dart';

// Wire shapes to domain models and back (pure field maps). A body that
// breaks the contract (an unknown difficulty) throws `FormatException`, so
// `apiCall` turns it into `ApiMalformed`.

extension CategoryDtoMapper on CategoryDto {
  TriviaCategory toDomain() => TriviaCategory(
    id: id,
    name: name,
    questionCount: questionCount,
    image: ApiImage(path: imageUrl),
  );
}

extension QuestionDtoMapper on QuestionDto {
  TriviaQuestion toDomain() => TriviaQuestion(
    id: id,
    prompt: prompt,
    choices: [for (final c in choices) TriviaChoice(id: c.id, text: c.text)],
    correctChoiceId: correctChoiceId,
    limitMs: timeLimitSeconds * 1000,
    image: switch (imageUrl) {
      final path? => ApiImage(path: path),
      null => null,
    },
    comicId: switch (comicId) {
      final id? => ComicId(id),
      null => null,
    },
  );
}

extension RoundDtoMapper on RoundDto {
  TriviaRound toDomain() => TriviaRound(
    id: roundId,
    category: category,
    difficulty:
        TriviaDifficulty.fromWire(difficulty) ??
        (throw FormatException('Unknown difficulty', difficulty)),
    seed: seed,
    questions: [for (final q in questions) q.toDomain()],
  );
}

extension ResultDtoMapper on ResultDto {
  ServerResult toDomain() => ServerResult(
    score: score,
    correct: correct,
    bestScore: bestScore,
    isNewBest: isNewBest,
    points: [for (final b in breakdown) b.points],
  );
}

extension BestListDtoMapper on BestListDto {
  /// Category id to best score.
  Map<String, int> toDomain() => {
    for (final b in best) b.category: b.bestScore,
  };
}

/// The body that submits [answers] of [roundId]: every answer, in round
/// order; `hint` only on the hinted one.
ResultRequestDto resultRequest(
  String roundId,
  List<AnsweredQuestion> answers,
) => ResultRequestDto(
  roundId: roundId,
  answers: [
    for (final a in answers)
      AnswerDto(
        questionId: a.questionId,
        choiceId: a.choiceId,
        elapsedMs: a.elapsedMs,
        hint: a.hint ? true : null,
      ),
  ],
);
