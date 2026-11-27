import 'package:flutter_test/flutter_test.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// A test-only domain: no routes of its own, one scenario that replaces the
/// results route with one that keeps the contract's shape but scores every
/// round [_ScoreOverride.score]. So the server and the engine disagree.
final class _ScoreOverride implements MockDomain {
  const _ScoreOverride(this.score);

  final int score;

  static const String scenario = 'trivia.test_score_override';

  @override
  String get name => 'trivia_test_override';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {}

  @override
  Map<String, MockScenario> get scenarios => {
    scenario: MockScenario(
      scenario,
      overrides: {
        'POST /v1/me/trivia/results': (request, context) {
          final body = request.body! as Map<Object?, Object?>;
          final answers = (body['answers']! as List)
              .cast<Map<Object?, Object?>>();
          return MockResponse.ok({
            'roundId': body['roundId'],
            'category': 'all',
            'score': score,
            'correct': answers.length,
            'bestScore': score,
            'isNewBest': true,
            'breakdown': [
              for (final (i, a) in answers.indexed)
                {
                  'questionId': a['questionId'],
                  'outcome': 'correct',
                  'points': i == 0 ? score : 0,
                },
            ],
          });
        },
      },
    ),
  };
}

/// Usage: the server scores every round {999}
///
/// From now on `POST /v1/me/trivia/results` answers [score] for any round,
/// whatever the answers: a server whose score differs from the engine's.
Future<void> theServerScoresEveryRound(WidgetTester tester, int score) async {
  final backend = McTestSession.current.backend;
  backend.useDomain(_ScoreOverride(score));
  backend.backend.useScenario(_ScoreOverride.scenario);
}
