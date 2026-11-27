import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/trivia_quiz_env.dart';

/// Usage: the results show {9} correct and the score the server saved
///
/// The score shown is what the server makes of the answers the app sent:
/// the last `POST /v1/me/trivia/results` body, scored again on a fresh
/// backend (an oracle that is not feature code).
Future<void> theResultsShowCorrectAndTheScoreTheServerSaved(
  WidgetTester tester,
  int correct,
) async {
  await tester.pump();
  final post = McTestSession.current.backend.requests.lastWhere(
    (r) => r.routeKey == 'POST /v1/me/trivia/results',
  );
  final fresh = MockBackend(domains: [const TriviaMockDomain()]);
  final response = await tester.runAsync(
    () => fresh.createDio().post<Map<String, Object?>>(
      'v1/me/trivia/results',
      data: post.body,
      options: Options(
        headers: {'Authorization': 'Bearer ${mintAccessToken('u-101', 1)}'},
      ),
    ),
  );
  final server = response!.data!;
  expect(server['correct'], correct);
  expect(textOf(tester, resultsScoreKey), '${server['score']}');
  expect(textOf(tester, resultsCorrectKey), '$correct of 10 correct');
}
