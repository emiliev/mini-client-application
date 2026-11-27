import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import '../oracle.dart';
import '../support.dart';

/// A round to fetch first, so a result can name its real choice ids.
typedef PlayRound = ({String category, String difficulty, int seed});

/// One request of the provider snapshots, run on a fresh default backend.
final class SnapshotCase {
  const SnapshotCase(
    this.method,
    this.path, {
    this.query,
    this.body,
    this.user = 'u-100',
    this.play,
    this.spec,
    this.tweak,
  });

  final String method;
  final String path;
  final Map<String, String>? query;
  final Object? body;

  /// The user whose access token is sent; `none` sends no bearer and
  /// `expired` sends u-100's expired one.
  final String user;

  /// When set (with [spec]), the body is built from this round: the answers
  /// of [spec] (`C0 W0x9`), with [tweak] applied to the list.
  final PlayRound? play;
  final String? spec;
  final void Function(List<Json> answers)? tweak;
}

const PlayRound _allEasy42 = (category: 'all', difficulty: 'easy', seed: 42);
const PlayRound _hard7 = (category: 'comics', difficulty: 'hard', seed: 7);

Map<String, String> _rounds(String c, String d, String s) => {
  'category': c,
  'difficulty': d,
  'seed': s,
};

/// The provider snapshot cases: name -> request.
///
/// Regenerate the files with
/// `fvm dart run utility/mc_fixtures_editorial/tool/update_snapshots.dart`
/// and review the diff: a snapshot change is a contract change and must be
/// reflected in `CONTRACT.md`.
final Map<String, SnapshotCase> snapshotCases = {
  'categories': const SnapshotCase(
    'GET',
    '/v1/trivia/categories',
    user: 'none',
  ),
  'round_all_easy_42': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('all', 'easy', '42'),
    user: 'none',
  ),
  'round_characters_medium_1': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('characters', 'medium', '1'),
    user: 'none',
  ),
  'round_comics_hard_max_seed': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('comics', 'hard', '2147483647'),
    user: 'none',
  ),
  'round_creators_easy_0': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('creators', 'easy', '0'),
    user: 'none',
  ),
  'round_unknown_category': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('nope', 'easy', '42'),
    user: 'none',
  ),
  'round_invalid_difficulty': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('all', 'extreme', '42'),
    user: 'none',
  ),
  'round_invalid_seed': SnapshotCase(
    'GET',
    '/v1/trivia/rounds',
    query: _rounds('all', 'easy', '-1'),
    user: 'none',
  ),
  'result_mixed_streaks': SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _allEasy42,
    spec: 'C0 C0 C0 W0 C0 C0 N0 C0 C0 C0',
  ),
  'result_hard_time_bonus': SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _hard7,
    spec: 'C1000 C2000 C3000 W0 N0 C9999 C10000 W500 C3333 C0',
  ),
  'result_zero_first_for_collector': SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    user: 'u-101',
    play: _allEasy42,
    spec: 'W0x10',
  ),
  'result_below_seeded_best': SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _allEasy42,
    spec: 'C0 W0x9',
  ),
  'best': const SnapshotCase('GET', '/v1/me/trivia/best'),
  'best_other_user': const SnapshotCase(
    'GET',
    '/v1/me/trivia/best',
    user: 'u-101',
  ),
  'unauthenticated': const SnapshotCase(
    'GET',
    '/v1/me/trivia/best',
    user: 'none',
  ),
  'expired_token': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    user: 'expired',
    body: {'roundId': 'r-all-easy-42', 'answers': <Object?>[]},
  ),
  'invalid_body': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    body: [1, 2],
  ),
  'unknown_round': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    body: {'roundId': 'r-all-easy-007', 'answers': <Object?>[]},
  ),
  'answer_count_mismatch': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    body: {'roundId': 'r-all-easy-42', 'answers': <Object?>[]},
  ),
  'unknown_question': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _allEasy42,
    spec: 'C0x10',
    tweak: _unknownQuestion,
  ),
  'duplicate_answer': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _allEasy42,
    spec: 'C0x10',
    tweak: _duplicate,
  ),
  'unknown_choice': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _allEasy42,
    spec: 'C0x10',
    tweak: _unknownChoice,
  ),
  'invalid_elapsed': const SnapshotCase(
    'POST',
    '/v1/me/trivia/results',
    play: _allEasy42,
    spec: 'C0x10',
    tweak: _negativeElapsed,
  ),
};

void _unknownQuestion(List<Json> answers) =>
    answers[3] = {...answers[3], 'questionId': 'q-nothing-01'};
void _duplicate(List<Json> answers) => answers[5] = {...answers[0]};
void _unknownChoice(List<Json> answers) =>
    answers[2] = {...answers[2], 'choiceId': 'c9'};
void _negativeElapsed(List<Json> answers) =>
    answers[4] = {...answers[4], 'elapsedMs': -1};

MockBackend snapshotBackend() =>
    MockBackend(domains: [const TriviaMockDomain()]);

/// Runs one case and returns `{"request", "status", "body"}`.
Future<Map<String, Object?>> runSnapshotCase(SnapshotCase c) async {
  final backend = snapshotBackend();
  final headers = switch (c.user) {
    'none' => <String, String>{},
    'expired' => {'Authorization': 'Bearer ${expiredAccessToken('u-100')}'},
    final id => {'Authorization': 'Bearer ${mintAccessToken(id, 1)}'},
  };
  Object? body = c.body;
  if (c.play != null) {
    final play = c.play!;
    final round = await fetchRound(
      jsonDio(backend),
      category: play.category,
      difficulty: play.difficulty,
      seed: play.seed,
    );
    final answers = answersFor(round, parseAnswers(c.spec!));
    c.tweak?.call(answers);
    body = {'roundId': round['roundId'], 'answers': answers};
  }
  final response = await backend.createDio().request<String>(
    c.path,
    data: body,
    queryParameters: c.query,
    options: Options(
      method: c.method,
      headers: headers,
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
    ),
  );
  final text = response.data;
  final query = c.query == null
      ? ''
      : '?${c.query!.entries.map((e) => '${e.key}=${e.value}').join('&')}';
  return {
    'request': '${c.method} ${c.path}$query as ${c.user}',
    if (body != null) 'requestBody': body,
    'status': response.statusCode,
    'body': text == null || text.isEmpty ? null : jsonDecode(text),
  };
}
