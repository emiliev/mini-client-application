import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:retrofit/retrofit.dart';
import 'package:trivia_quiz/src/domain/model/trivia_dto.dart';

part 'trivia_quiz_api.g.dart';

/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature): the IX archetype's three endpoints (plan 01 §6.1) plus the best
/// scores (`mc_fixtures_editorial` CONTRACT.md). The `Dio` comes from the
/// root container (a `RootImport`), with the auth interceptor on it, so the
/// `v1/me/...` calls carry the bearer.
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class TriviaQuizApi {
  @factoryMethod
  factory TriviaQuizApi(Dio dio) = _TriviaQuizApi;

  @GET('v1/trivia/categories')
  Future<CategoriesDto> getCategories();

  /// One round of 10 questions; `400` for an unknown category, difficulty or
  /// seed.
  @GET('v1/trivia/rounds')
  Future<RoundDto> getRound(
    @Query('category') String category,
    @Query('difficulty') String difficulty,
    @Query('seed') int seed,
  );

  /// Scores a finished round on the server and keeps the best. Needs the
  /// bearer. Pass `authPinned(epoch)` as [extras] to send it only for that
  /// session.
  @POST('v1/me/trivia/results')
  Future<ResultDto> postResult(
    @Body() ResultRequestDto body, {
    @Extras() Map<String, dynamic> extras = const {},
  });

  /// The signed-in user's best score per category played. Needs the bearer.
  /// Pass `authPinned(epoch)` as [extras] to send it only for that session.
  @GET('v1/me/trivia/best')
  Future<BestListDto> getBest({
    @Extras() Map<String, dynamic> extras = const {},
  });
}
