import 'dart:async';

import 'package:mc_fixtures_editorial/src/data/bank.dart';
import 'package:mc_fixtures_editorial/src/data/round.dart';
import 'package:mc_fixtures_editorial/src/data/scoring.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

const String _stateKey = 'trivia.state';
const String _emptyStateKey = 'trivia.state.empty';

/// The best scores the default set starts with (user -> category -> score).
const Map<String, Map<String, int>> seededBest = {
  'u-100': {'all': 870, 'characters': 1340},
};

/// A category's display data.
typedef _CategoryInfo = ({String id, String name, String imageUrl});

const List<_CategoryInfo> _categories = [
  (
    id: allCategory,
    name: 'All categories',
    imageUrl: 'mock-asset://characters/000',
  ),
  (
    id: 'characters',
    name: 'Characters',
    imageUrl: 'mock-asset://characters/003',
  ),
  (id: 'comics', name: 'Comics', imageUrl: 'mock-asset://characters/011'),
  (id: 'creators', name: 'Creators', imageUrl: 'mock-asset://characters/019'),
];

/// Every user's best score per category.
final class TriviaState {
  TriviaState(this.bestByUser);

  final Map<String, Map<String, int>> bestByUser;
}

TriviaState _state(MockContext context, {required bool empty}) {
  final key = empty ? _emptyStateKey : _stateKey;
  final existing = context.store[key];
  if (existing != null) {
    return existing as TriviaState;
  }
  return context.store[key] = TriviaState({
    for (final user in fixtureUsers)
      user.id: {if (!empty) ...?seededBest[user.id]},
  });
}

/// The questions of the backend: none for the `empty` mode.
List<TriviaQuestion> _bank(MockContext context, {required bool empty}) =>
    empty ? const [] : triviaQuestionBank(context.seed);

/// The category ids a round may be asked for.
List<String> _categoryIds({required bool empty}) =>
    empty ? const [] : [for (final c in _categories) c.id];

MockResponse _unauthenticated() => MockResponse.error(
  401,
  'unauthenticated',
  'A valid bearer token is required',
);

MockResponse _invalid(
  String code,
  String message,
  Map<String, Object?> extra,
) => MockResponse.error(400, code, message, extra: extra);

/// Wraps [body] with the bearer check; [body] gets the signed-in user.
MockHandler _authed(
  FutureOr<MockResponse> Function(
    FixtureUser user,
    MockRequest request,
    MockContext context,
  )
  body,
) => (request, context) {
  final user = userForAuthorization(request.headers['authorization']);
  return user == null ? _unauthenticated() : body(user, request, context);
};

/// `GET /v1/trivia/categories`.
MockHandler listCategories({required bool empty}) => (request, context) {
  if (empty) {
    return const MockResponse.ok({'categories': <Object?>[]});
  }
  final bank = _bank(context, empty: empty);
  return MockResponse.ok({
    'categories': [
      for (final c in _categories)
        {
          'id': c.id,
          'name': c.name,
          'questionCount': c.id == allCategory
              ? bank.length
              : bank.where((q) => q.category == c.id).length,
          'imageUrl': c.imageUrl,
        },
    ],
  });
};

/// `GET /v1/trivia/rounds?category=&difficulty=&seed=`. Checks run in that
/// order; all three are required.
MockHandler getRound({required bool empty}) => (request, context) {
  final category = request.query['category'];
  if (!_categoryIds(empty: empty).contains(category)) {
    return _invalid(
      'unknown_category',
      'category must be one of ${_categoryIds(empty: false).join(', ')}',
      {'parameter': 'category'},
    );
  }
  final difficulty = request.query['difficulty'];
  if (!difficulties.contains(difficulty)) {
    return _invalid(
      'invalid_difficulty',
      'difficulty must be one of ${difficulties.join(', ')}',
      {'parameter': 'difficulty'},
    );
  }
  final seed = parseRoundSeed(request.query['seed']);
  if (seed == null) {
    return _invalid(
      'invalid_seed',
      'seed must be an integer from 0 to $maxRoundSeed',
      {'parameter': 'seed'},
    );
  }
  final spec = RoundSpec(category!, difficulty!, seed);
  final questions = buildRound(_bank(context, empty: empty), spec);
  return MockResponse.ok({
    'roundId': spec.roundId,
    'category': category,
    'difficulty': difficulty,
    'seed': seed,
    'questions': [for (final q in questions) q.toJson()],
  });
};

MockResponse _badBody(String message) =>
    _invalid('invalid_body', message, {'parameter': 'body'});

/// The answers of the body as a list of maps, or an error.
({List<Map<Object?, Object?>>? answers, MockResponse? error}) _readAnswers(
  Object? raw,
) {
  if (raw is! List) {
    return (answers: null, error: _badBody('answers must be a list'));
  }
  final answers = <Map<Object?, Object?>>[];
  for (final entry in raw) {
    if (entry is! Map ||
        entry['questionId'] is! String ||
        (entry['choiceId'] != null && entry['choiceId'] is! String)) {
      return (
        answers: null,
        error: _badBody(
          'each answer needs a questionId string and a choiceId string or '
          'null',
        ),
      );
    }
    answers.add(entry.cast<Object?, Object?>());
  }
  return (answers: answers, error: null);
}

/// `POST /v1/me/trivia/results` with `{roundId, answers}`: scores the round
/// on the server and keeps the best score per category.
MockHandler postResult({required bool empty}) =>
    _authed((user, request, context) {
      final body = request.body;
      if (body is! Map || body['roundId'] is! String) {
        return _badBody('Expected an object with a roundId string');
      }
      final (:answers, :error) = _readAnswers(body['answers']);
      if (answers == null) {
        return error!;
      }
      final spec = parseRoundId(
        body['roundId'] as String,
        _categoryIds(empty: empty),
      );
      if (spec == null) {
        return _invalid(
          'unknown_round',
          'No round "${body['roundId']}"',
          {'parameter': 'roundId'},
        );
      }
      final questions = buildRound(_bank(context, empty: empty), spec);
      if (answers.length != questions.length) {
        return _invalid(
          'answer_count_mismatch',
          'the round has ${questions.length} questions, '
              'got ${answers.length} answers',
          {'parameter': 'answers', 'expected': questions.length},
        );
      }
      final byId = {for (final q in questions) q.id: q};
      for (final a in answers) {
        if (!byId.containsKey(a['questionId'])) {
          return _invalid(
            'unknown_question',
            'question ${a['questionId']} is not in this round',
            {'parameter': 'answers', 'questionId': a['questionId']},
          );
        }
      }
      final seen = <Object?>{};
      for (final a in answers) {
        if (!seen.add(a['questionId'])) {
          return _invalid(
            'duplicate_answer',
            'question ${a['questionId']} is answered more than once',
            {'parameter': 'answers', 'questionId': a['questionId']},
          );
        }
      }
      for (final a in answers) {
        final choice = a['choiceId'];
        if (choice != null &&
            !byId[a['questionId']]!.choices.any((c) => c.id == choice)) {
          return _invalid(
            'unknown_choice',
            'choice $choice is not a choice of ${a['questionId']}',
            {
              'parameter': 'answers',
              'questionId': a['questionId'],
              'choiceId': choice,
            },
          );
        }
      }
      for (final a in answers) {
        final elapsed = a['elapsedMs'];
        if (elapsed is! int || elapsed < 0) {
          return _invalid(
            'invalid_elapsed',
            'elapsedMs must be an integer of at least 0',
            {'parameter': 'answers', 'questionId': a['questionId']},
          );
        }
      }
      final result = scoreRound(questions, {
        for (final a in answers)
          a['questionId']! as String: SubmittedAnswer(
            a['choiceId'] as String?,
            a['elapsedMs']! as int,
          ),
      });
      final best = _state(context, empty: empty).bestByUser[user.id]!;
      final before = best[spec.category] ?? 0;
      final bestScore = result.score > before ? result.score : before;
      best[spec.category] = bestScore;
      return MockResponse.ok({
        'roundId': spec.roundId,
        'category': spec.category,
        'score': result.score,
        'correct': result.correct,
        'bestScore': bestScore,
        'isNewBest': result.score > before,
        'breakdown': [for (final a in result.answers) a.toJson()],
      });
    });

/// `GET /v1/me/trivia/best`: the user's best score per category played.
MockHandler getBest({required bool empty}) => _authed((user, request, context) {
  final best = _state(context, empty: empty).bestByUser[user.id]!;
  final ids = best.keys.toList()..sort();
  return MockResponse.ok({
    'best': [
      for (final id in ids) {'category': id, 'bestScore': best[id]},
    ],
  });
});

/// The `server_error` set: the exact body the `trivia.server_error`
/// scenario's `FailureRule` produces, so both fail the same way.
MockResponse serverError(MockRequest request, MockContext context) =>
    MockResponse.error(
      500,
      'injected_failure',
      'Injected HTTP 500 for ${request.routeKey}',
    );
