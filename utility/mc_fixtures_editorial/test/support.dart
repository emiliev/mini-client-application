import 'package:dio/dio.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import 'oracle.dart';

/// A backend serving the trivia domain (the default set), optionally with
/// the comics and characters it is generated from.
MockBackend triviaBackend({
  int seed = 42,
  MockDomain domain = const TriviaMockDomain(),
  bool withSources = false,
}) => MockBackend(
  seed: seed,
  domains: [
    domain,
    if (withSources) ...[
      const ComicsMockDomain(),
      const CharactersMockDomain(),
    ],
  ],
);

/// A Dio that never throws on a status and returns the raw body text.
Dio plainDio(MockBackend backend) {
  final dio = backend.createDio();
  dio.options.validateStatus = (_) => true;
  dio.options.responseType = ResponseType.plain;
  return dio;
}

/// A Dio that never throws on a status and decodes JSON.
Dio jsonDio(MockBackend backend) =>
    backend.createDio()..options.validateStatus = (_) => true;

/// The bearer header of a valid access token for [userId].
Map<String, String> bearer(String userId, [int n = 1]) => {
  'Authorization': 'Bearer ${mintAccessToken(userId, n)}',
};

const String reader = 'u-100';
const String collector = 'u-101';

Future<Response<T>> call<T>(
  Dio dio,
  String method,
  String path, {
  Object? body,
  Map<String, String>? headers,
  Map<String, Object?>? query,
}) => dio.request<T>(
  path,
  data: body,
  queryParameters: query,
  options: Options(method: method, headers: headers),
);

typedef Json = Map<String, Object?>;

/// `GET /v1/trivia/rounds`, decoded.
Future<Json> fetchRound(
  Dio dio, {
  String category = 'all',
  String difficulty = 'easy',
  int seed = 42,
}) async {
  final response = await call<Json>(
    dio,
    'GET',
    '/v1/trivia/rounds',
    query: {'category': category, 'difficulty': difficulty, 'seed': seed},
  );
  expectStatus(response, 200);
  return response.data!;
}

void expectStatus(Response<Object?> response, int status) {
  if (response.statusCode != status) {
    throw StateError(
      'expected $status, got ${response.statusCode}: ${response.data}',
    );
  }
}

List<Json> questionsOf(Json round) =>
    (round['questions']! as List).cast<Json>();

List<Json> choicesOf(Json question) =>
    (question['choices']! as List).cast<Json>();

/// A choice id of [question] that is not the correct one.
String wrongChoice(Json question) =>
    choicesOf(
          question,
        )
        .map((c) => c['id']! as String)
        .firstWhere((id) => id != question['correctChoiceId']);

/// The answers a spec asks for, for the questions of [round], in round order;
/// the positions in [hinted] carry `"hint": true` (T-0064).
List<Json> answersFor(
  Json round,
  List<Answer> spec, {
  Set<int> hinted = const {},
}) {
  final questions = questionsOf(round);
  assert(questions.length == spec.length, 'one spec entry per question');
  return [
    for (var i = 0; i < questions.length; i++)
      {
        'questionId': questions[i]['id'],
        'choiceId': switch (spec[i].kind) {
          'C' => questions[i]['correctChoiceId'],
          'W' => wrongChoice(questions[i]),
          _ => null,
        },
        'elapsedMs': spec[i].elapsedMs,
        if (hinted.contains(i)) 'hint': true,
      },
  ];
}

/// `POST /v1/me/trivia/results`.
Future<Response<Json>> postResult(
  Dio dio,
  Object? body, {
  String user = reader,
}) => call<Json>(
  dio,
  'POST',
  '/v1/me/trivia/results',
  body: body,
  headers: bearer(user),
);

/// Plays [spec] on the round and returns the decoded result.
Future<Json> play(
  Dio dio,
  Json round,
  List<Answer> spec, {
  String user = reader,
  Set<int> hinted = const {},
}) async {
  final response = await postResult(dio, {
    'roundId': round['roundId'],
    'answers': answersFor(round, spec, hinted: hinted),
  }, user: user);
  expectStatus(response, 200);
  return response.data!;
}

/// `GET /v1/me/trivia/best` as a map category -> best score.
Future<Map<String, int>> bestOf(Dio dio, {String user = reader}) async {
  final response = await call<Json>(
    dio,
    'GET',
    '/v1/me/trivia/best',
    headers: bearer(user),
  );
  expectStatus(response, 200);
  return {
    for (final e in (response.data!['best']! as List).cast<Json>())
      e['category']! as String: e['bestScore']! as int,
  };
}
