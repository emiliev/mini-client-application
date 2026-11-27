import 'package:freezed_annotation/freezed_annotation.dart';

part 'trivia_dto.freezed.dart';
part 'trivia_dto.g.dart';

// The wire shapes this feature reads and writes, as `mc_fixtures_editorial`'s
// CONTRACT.md defines them. The contract test pins each to the served JSON,
// so a body round-trips byte for byte.
//
// The JSON flags are spelled out (R30): under the Bazel shim a bare `@freezed`
// silently loses its JSON (F-0025).

/// One category of `GET v1/trivia/categories`.
@Freezed(fromJson: true, toJson: true)
abstract class CategoryDto with _$CategoryDto {
  const factory CategoryDto({
    required String id,
    required String name,
    required int questionCount,
    required String imageUrl,
  }) = _CategoryDto;

  factory CategoryDto.fromJson(Map<String, dynamic> json) =>
      _$CategoryDtoFromJson(json);
}

/// `GET v1/trivia/categories`.
@Freezed(fromJson: true, toJson: true)
abstract class CategoriesDto with _$CategoriesDto {
  @JsonSerializable(explicitToJson: true)
  const factory CategoriesDto({required List<CategoryDto> categories}) =
      _CategoriesDto;

  factory CategoriesDto.fromJson(Map<String, dynamic> json) =>
      _$CategoriesDtoFromJson(json);
}

/// One answer option.
@Freezed(fromJson: true, toJson: true)
abstract class ChoiceDto with _$ChoiceDto {
  const factory ChoiceDto({required String id, required String text}) =
      _ChoiceDto;

  factory ChoiceDto.fromJson(Map<String, dynamic> json) =>
      _$ChoiceDtoFromJson(json);
}

/// One question of a round. [imageUrl] and [comicId] are optional on the
/// wire.
@Freezed(fromJson: true, toJson: true)
abstract class QuestionDto with _$QuestionDto {
  @JsonSerializable(explicitToJson: true, includeIfNull: false)
  const factory QuestionDto({
    required String id,
    required String category,
    required String difficulty,
    required String prompt,
    required List<ChoiceDto> choices,
    required String correctChoiceId,
    required int timeLimitSeconds,
    String? imageUrl,
    int? comicId,
  }) = _QuestionDto;

  factory QuestionDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionDtoFromJson(json);
}

/// `GET v1/trivia/rounds`: ten questions in round order.
@Freezed(fromJson: true, toJson: true)
abstract class RoundDto with _$RoundDto {
  @JsonSerializable(explicitToJson: true)
  const factory RoundDto({
    required String roundId,
    required String category,
    required String difficulty,
    required int seed,
    required List<QuestionDto> questions,
  }) = _RoundDto;

  factory RoundDto.fromJson(Map<String, dynamic> json) =>
      _$RoundDtoFromJson(json);
}

/// One answer of `POST v1/me/trivia/results`. `choiceId` is always sent (null
/// is the explicit "no answer"); `hint` only when the hint was used.
@Freezed(fromJson: true, toJson: true)
abstract class AnswerDto with _$AnswerDto {
  const factory AnswerDto({
    required String questionId,
    required String? choiceId,
    required int elapsedMs,
    @JsonKey(includeIfNull: false) bool? hint,
  }) = _AnswerDto;

  factory AnswerDto.fromJson(Map<String, dynamic> json) =>
      _$AnswerDtoFromJson(json);
}

/// The body of `POST v1/me/trivia/results`.
@Freezed(fromJson: true, toJson: true)
abstract class ResultRequestDto with _$ResultRequestDto {
  @JsonSerializable(explicitToJson: true)
  const factory ResultRequestDto({
    required String roundId,
    required List<AnswerDto> answers,
  }) = _ResultRequestDto;

  factory ResultRequestDto.fromJson(Map<String, dynamic> json) =>
      _$ResultRequestDtoFromJson(json);
}

/// One scored answer of the server's breakdown.
@Freezed(fromJson: true, toJson: true)
abstract class BreakdownDto with _$BreakdownDto {
  @JsonSerializable(includeIfNull: false)
  const factory BreakdownDto({
    required String questionId,
    required String outcome,
    required int points,
    bool? hint,
  }) = _BreakdownDto;

  factory BreakdownDto.fromJson(Map<String, dynamic> json) =>
      _$BreakdownDtoFromJson(json);
}

/// The answer of `POST v1/me/trivia/results`: the server's score, which is
/// authoritative.
@Freezed(fromJson: true, toJson: true)
abstract class ResultDto with _$ResultDto {
  @JsonSerializable(explicitToJson: true)
  const factory ResultDto({
    required String roundId,
    required String category,
    required int score,
    required int correct,
    required int bestScore,
    required bool isNewBest,
    required List<BreakdownDto> breakdown,
  }) = _ResultDto;

  factory ResultDto.fromJson(Map<String, dynamic> json) =>
      _$ResultDtoFromJson(json);
}

/// One category's best score.
@Freezed(fromJson: true, toJson: true)
abstract class BestDto with _$BestDto {
  const factory BestDto({required String category, required int bestScore}) =
      _BestDto;

  factory BestDto.fromJson(Map<String, dynamic> json) =>
      _$BestDtoFromJson(json);
}

/// `GET v1/me/trivia/best`.
@Freezed(fromJson: true, toJson: true)
abstract class BestListDto with _$BestListDto {
  @JsonSerializable(explicitToJson: true)
  const factory BestListDto({required List<BestDto> best}) = _BestListDto;

  factory BestListDto.fromJson(Map<String, dynamic> json) =>
      _$BestListDtoFromJson(json);
}
