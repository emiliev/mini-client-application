import 'package:injectable/injectable.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:trivia_quiz/src/domain/api/trivia_quiz_api.dart';
import 'package:trivia_quiz/src/domain/engine/trivia_engine.dart';
import 'package:trivia_quiz/src/domain/model/trivia.dart';
import 'package:trivia_quiz/src/domain/model/trivia_mapper.dart';

/// The quiz's data as values, never exceptions. Stateless (Tide): the round
/// being played lives in the play bloc's engine, what the flow shows in its
/// state.
@injectable
class TriviaQuizRepository {
  const TriviaQuizRepository(this._api);

  final TriviaQuizApi _api;

  Future<Result<List<TriviaCategory>, ApiFailure>> fetchCategories() => apiCall(
    () async => [
      for (final c in (await _api.getCategories()).categories) c.toDomain(),
    ],
  );

  /// The round of [category], [difficulty] and [seed]: the same three always
  /// give the same ten questions (CONTRACT.md). A category, difficulty or
  /// seed the server does not know is an [ApiClientError] (`400`).
  Future<Result<TriviaRound, ApiFailure>> fetchRound({
    required String category,
    required String difficulty,
    required int seed,
  }) => apiCall(
    () async => (await _api.getRound(category, difficulty, seed)).toDomain(),
  );

  /// The signed-in user's best per category, read for the session [epoch]
  /// (pinned, T-0050).
  Future<Result<Map<String, int>, ApiFailure>> fetchBest({
    required int epoch,
  }) => apiCall(
    () async => (await _api.getBest(extras: authPinned(epoch))).toDomain(),
  );

  /// Submits the answers of round [roundId] and returns the server's score.
  /// The request is pinned to the session [epoch] the caller checked: if the
  /// session changed before it was sent, nothing is sent and the answer is
  /// [ApiUnauthorized] (T-0050), so a result never goes out under another
  /// user's bearer.
  Future<Result<ServerResult, ApiFailure>> submit(
    String roundId,
    List<AnsweredQuestion> answers, {
    required int epoch,
  }) => apiCall(
    () async => (await _api.postResult(
      resultRequest(roundId, answers),
      extras: authPinned(epoch),
    )).toDomain(),
  );
}
