import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_editorial/mc_fixtures_editorial.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

import '../support.dart';
import 'snapshot_cases.dart';

/// The package directory in the test's runfiles (Bazel) or the checkout.
Directory _dir(String relative) {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null) '$srcDir/$workspace/$relative',
    relative,
  ]) {
    if (Directory(candidate).existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError('$relative not found from ${Directory.current}');
}

/// What the characters and comics endpoints say, gathered once per seed.
final class _Truth {
  _Truth(this.dio);

  final Dio dio;
  final Set<String> teams = {};
  final Set<String> powers = {};
  final Map<int, Json> _characters = {};

  Future<Json> get(String path, [Map<String, Object?>? query]) async {
    final response = await call<Json>(dio, 'GET', path, query: query);
    if (response.statusCode != 200) {
      throw StateError('GET $path -> ${response.statusCode}');
    }
    return response.data!;
  }

  Future<void> load() async {
    for (var id = 100000; id < 101500; id++) {
      final c = await get('/v1/characters/$id');
      _characters[id] = c;
      teams.add(c['team']! as String);
      powers.addAll((c['powers']! as List).cast<String>());
    }
  }

  Json character(int id) => _characters[id]!;

  /// The characters whose name is exactly [name] (via the list endpoint).
  Future<List<Json>> charactersNamed(String name) async {
    final page = await get('/v1/characters', {
      'nameStartsWith': name,
      'limit': 100,
    });
    return [
      for (final r in (page['results']! as List).cast<Json>())
        if (r['name'] == name) character(r['id']! as int),
    ];
  }

  /// The comics whose title is exactly [title].
  Future<List<Json>> comicsTitled(String title) async {
    final page = await get('/v1/comics', {
      'titleStartsWith': title,
      'limit': 100,
    });
    return [
      for (final r in (page['results']! as List).cast<Json>())
        if (r['title'] == title) r,
    ];
  }
}

final RegExp _year = RegExp(r'^\d{4}$');

/// Money as the contract writes it, from a price in cents.
String _price(int cents) =>
    '\$${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// Checks one question against the endpoints; null when every fact agrees.
Future<String?> _verify(_Truth truth, TriviaQuestion q) async {
  final facts = q.facts;
  final kind = facts['kind']! as String;
  final correct = q.correctText;
  final wrong = [
    for (final c in q.choices)
      if (c.id != q.correctChoiceId) c.text,
  ];
  if (q.choices.length != 4 || wrong.length != 3) {
    return 'not 4 choices';
  }
  if ({correct, ...wrong}.length != 4) {
    return 'choices not distinct';
  }
  String? years(int truthYear) {
    if (correct != '$truthYear') {
      return 'correct $correct, endpoint says $truthYear';
    }
    for (final w in wrong) {
      final year = _year.hasMatch(w) ? int.parse(w) : null;
      if (year == null || year == truthYear || (year - truthYear).abs() > 4) {
        return 'implausible year $w for $truthYear';
      }
    }
    return null;
  }

  switch (kind) {
    case 'character_team':
      final c = truth.character(facts['characterId']! as int);
      if (!q.prompt.contains(c['name']! as String)) {
        return 'prompt lacks the name';
      }
      if (correct != c['team']) {
        return 'team $correct, endpoint ${c['team']}';
      }
      if (wrong.any((w) => w == c['team'] || !truth.teams.contains(w))) {
        return 'a wrong team is true or not a team';
      }
    case 'character_power':
      final c = truth.character(facts['characterId']! as int);
      final own = (c['powers']! as List).cast<String>();
      if (!q.prompt.contains(c['name']! as String)) {
        return 'prompt lacks the name';
      }
      if (!own.contains(correct)) {
        return '$correct is not a power of ${c['name']}';
      }
      if (wrong.any((w) => own.contains(w) || !truth.powers.contains(w))) {
        return 'a wrong power is true or not a power';
      }
    case 'character_debut_year':
      final c = truth.character(facts['characterId']! as int);
      if (!q.prompt.contains(c['name']! as String)) {
        return 'prompt lacks the name';
      }
      final bad = years(c['firstAppearanceYear']! as int);
      if (bad != null) {
        return bad;
      }
    case 'character_first_comic':
      final id = facts['characterId']! as int;
      final c = truth.character(id);
      if (!q.prompt.contains(c['name']! as String)) {
        return 'prompt lacks the name';
      }
      final page = await truth.get('/v1/comics', {
        'characterId': id,
        'orderBy': 'releaseDate',
        'limit': 100,
      });
      final results = (page['results']! as List).cast<Json>();
      if (results.length < 2 || page['total'] != results.length) {
        return 'needs 2 to 100 comics, got ${page['total']}';
      }
      if (correct != results.first['title']) {
        return 'first comic is ${results.first['title']}, not $correct';
      }
      final titles = {for (final r in results) r['title']};
      for (final w in wrong) {
        if (titles.contains(w) || (await truth.comicsTitled(w)).isEmpty) {
          return 'wrong comic "$w" features the character or does not exist';
        }
      }
    case 'character_debut':
      final year = facts['year']! as int;
      final c = truth.character(facts['characterId']! as int);
      if (!q.prompt.contains('$year')) {
        return 'prompt lacks the year';
      }
      if (c['name'] != correct || c['firstAppearanceYear'] != year) {
        return 'the correct character did not first appear in $year';
      }
      for (final w in wrong) {
        final named = await truth.charactersNamed(w);
        if (named.isEmpty ||
            named.any((n) => n['firstAppearanceYear'] == year)) {
          return 'wrong character "$w" does not exist or debuted in $year';
        }
      }
    case 'comic_cast':
      final comic = await truth.get('/v1/comics/${facts['comicId']}');
      if (!q.prompt.contains(comic['title']! as String)) {
        return 'prompt lacks the title';
      }
      final cast = [
        for (final c in (comic['characters']! as List).cast<Json>()) c['name'],
      ];
      if (!cast.contains(correct)) {
        return '$correct is not in the cast';
      }
      for (final w in wrong) {
        if (cast.contains(w) || (await truth.charactersNamed(w)).isEmpty) {
          return 'wrong character "$w" is in the cast or does not exist';
        }
      }
    case 'comic_price':
      final comic = await truth.get('/v1/comics/${facts['comicId']}');
      if (!q.prompt.contains(comic['title']! as String)) {
        return 'prompt lacks the title';
      }
      final cents = (comic['price']! as Json)['amountCents']! as int;
      if (correct != _price(cents)) {
        return 'price $correct, endpoint $cents cents';
      }
      if (wrong.any((w) => !RegExp(r'^\$[2-5]\.99$').hasMatch(w))) {
        return 'a wrong price is not a real price';
      }
    case 'comic_year':
      final comic = await truth.get('/v1/comics/${facts['comicId']}');
      if (!q.prompt.contains(comic['title']! as String)) {
        return 'prompt lacks the title';
      }
      final bad = years(
        int.parse((comic['releaseDate']! as String).substring(0, 4)),
      );
      if (bad != null) {
        return bad;
      }
    case 'comic_pages':
      final comic = await truth.get('/v1/comics/${facts['comicId']}');
      if (!q.prompt.contains(comic['title']! as String)) {
        return 'prompt lacks the title';
      }
      if (correct != '${comic['pageCount']}') {
        return 'pages $correct, endpoint ${comic['pageCount']}';
      }
      const real = {'24', '32', '40', '48', '56'};
      if (wrong.any((w) => !real.contains(w) || w == correct)) {
        return 'a wrong page count is not a real one';
      }
    case 'series_start' || 'series_end':
      final series = await truth.get('/v1/series/${facts['seriesId']}');
      if (!q.prompt.contains(series['title']! as String)) {
        return 'prompt lacks the series title';
      }
      final bad = years(
        series[kind == 'series_start' ? 'startYear' : 'endYear']! as int,
      );
      if (bad != null) {
        return bad;
      }
    case 'creator_writer' || 'creator_penciller' || 'creator_inker':
      final comic = await truth.get('/v1/comics/${facts['comicId']}');
      if (!q.prompt.contains(comic['title']! as String)) {
        return 'prompt lacks the title';
      }
      final role = facts['role']! as String;
      if (kind != 'creator_$role') {
        return 'role does not match the template';
      }
      final holders = [
        for (final c in (comic['creators']! as List).cast<Json>())
          if (c['role'] == role) c['name'],
      ];
      if (holders.length != 1 || holders.single != correct) {
        return 'the $role is $holders, not $correct';
      }
      if (wrong.any(
        (w) => holders.contains(w) || !RegExp(r'^\w+ \w+$').hasMatch(w),
      )) {
        return 'a wrong creator holds the role or is not a name';
      }
    default:
      return 'unknown template $kind';
  }
  return null;
}

/// The image the question's subject has on its endpoint.
Future<String?> _expectedImage(_Truth truth, TriviaQuestion q) async {
  final facts = q.facts;
  if (facts.containsKey('seriesId')) {
    final series = await truth.get('/v1/series/${facts['seriesId']}');
    return (series['cover']! as Json)['path']! as String;
  }
  if (facts.containsKey('comicId')) {
    final comic = await truth.get('/v1/comics/${facts['comicId']}');
    return (comic['cover']! as Json)['path']! as String;
  }
  if (facts['kind'] == 'character_debut') {
    return null;
  }
  final c = truth.character(facts['characterId']! as int);
  return (c['thumbnail']! as Json)['path']! as String;
}

void main() {
  final trivia = _dir('utility/mc_fixtures_editorial');
  final media = _dir('utility/mc_fixtures_media');

  group('T-0060-AC4 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0060-AC4: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${trivia.path}/test/contract/snapshots/${entry.key}.json',
        );
        expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');
        final expected = jsonDecode(file.readAsStringSync());
        final actual = await runSnapshotCase(entry.value);
        expect(
          canonicalJson(actual),
          canonicalJson(expected),
          reason:
              'Contract drift in ${entry.key}. If intended, rerun '
              'tool/update_snapshots.dart and update CONTRACT.md.',
        );
      });
    }

    test('T-0060-AC4: no snapshot file lacks a case', () {
      final files = Directory('${trivia.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test('T-0060-AC4: every route and every error code has a snapshot', () {
      final requests = {
        for (final c in snapshotCases.values) '${c.method} ${c.path}',
      };
      expect(requests, containsAll(triviaRouteManifest));
      final codes = <Object?>{};
      for (final c in snapshotCases.values) {
        final file = File(
          '${trivia.path}/test/contract/snapshots/'
          '${snapshotCases.entries.firstWhere((e) => e.value == c).key}.json',
        );
        final body = (jsonDecode(file.readAsStringSync()) as Json)['body'];
        if (body is Map && body['error'] is Map) {
          codes.add((body['error'] as Map)['code']);
        }
      }
      expect(codes, {
        'unknown_category',
        'invalid_difficulty',
        'invalid_seed',
        'unknown_round',
        'answer_count_mismatch',
        'unknown_question',
        'duplicate_answer',
        'unknown_choice',
        'invalid_elapsed',
        'invalid_body',
        'unauthenticated',
      });
    });

    test('T-0060-AC4: the route manifest, the domain and the scenarios '
        'agree', () {
      final manifest = jsonDecode(
        File('${trivia.path}/fixtures/routes.json').readAsStringSync(),
      ) as Json;
      final backend = MockBackend(domains: [const TriviaMockDomain()]);
      expect([
        for (final r in backend.router.routes) r.key,
      ], manifest['routes']);
      expect(TriviaMockDomain.routeManifest, manifest['routes']);
      expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
      expect(manifest['domain'], const TriviaMockDomain().name);
    });

    test('T-0060-AC4: CONTRACT.md documents every route, scenario, set, '
        'error code and template', () {
      final doc = File('${trivia.path}/CONTRACT.md').readAsStringSync();
      for (final route in TriviaMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final scenario in const [
        'trivia.empty',
        'trivia.server_error',
        'trivia.slow',
      ]) {
        expect(doc, contains('`$scenario`'));
      }
      for (final set in editorialFixtureSets.keys) {
        expect(doc, contains('`$set`'));
      }
      for (final code in const [
        'unauthenticated',
        'unknown_category',
        'invalid_difficulty',
        'invalid_seed',
        'unknown_round',
        'answer_count_mismatch',
        'unknown_question',
        'duplicate_answer',
        'unknown_choice',
        'invalid_elapsed',
        'invalid_body',
        'injected_failure',
      ]) {
        expect(doc, contains('`$code`'), reason: code);
      }
      for (final template in triviaQuestionBank(
        42,
      ).map((q) => q.template).toSet()) {
        expect(doc, contains('`$template`'), reason: template);
      }
      for (final d in difficulties) {
        expect(
          doc,
          contains(
            '| `$d` | ${const {'easy': 20, 'medium': 15, 'hard': 10}[d]} |',
          ),
          reason: d,
        );
      }
    });
  });

  // Seed 4 holds a first-comic question whose character has two comics on
  // the same earliest date (the tie goes to the lower id).
  for (final seed in [42, 7, 4]) {
    group('T-0060-AC4 the facts agree with the endpoints (backend seed '
        '$seed)', () {
      late _Truth truth;
      late List<TriviaQuestion> bank;
      setUpAll(() async {
        truth = _Truth(jsonDio(triviaBackend(seed: seed, withSources: true)));
        await truth.load();
        bank = triviaQuestionBank(seed);
      });

      test('T-0060-AC4 seed $seed: every one of the bank\'s questions is '
          'true on the characters and comics endpoints', () async {
        final problems = <String>[];
        for (final q in bank) {
          final problem = await _verify(truth, q);
          if (problem != null) {
            problems.add('${q.id}: $problem');
          }
        }
        expect(problems, isEmpty);
        expect(bank, hasLength(336));
      });

      test('T-0060-AC4 seed $seed: each question\'s image is its subject\'s '
          'own picture', () async {
        for (final q in bank) {
          expect(q.imageUrl, await _expectedImage(truth, q), reason: q.id);
        }
      });

      test('T-0060-AC4 seed $seed: the checker catches a false fact '
          '(negative control)', () async {
        final q = bank.firstWhere((q) => q.template == 'comic_year');
        final wrongId = q.choices
            .firstWhere((c) => c.id != q.correctChoiceId)
            .id;
        final lie = TriviaQuestion(
          id: q.id,
          template: q.template,
          category: q.category,
          difficulty: q.difficulty,
          prompt: q.prompt,
          choices: q.choices,
          correctChoiceId: wrongId,
          facts: q.facts,
          imageUrl: q.imageUrl,
        );
        expect(await _verify(truth, q), isNull);
        expect(await _verify(truth, lie), isNotNull);
        // And a distractor that is also true is caught.
        final comic = bank.firstWhere(
          (q) => q.template == 'character_first_comic',
        );
        final features = TriviaQuestion(
          id: comic.id,
          template: comic.template,
          category: comic.category,
          difficulty: comic.difficulty,
          prompt: comic.prompt,
          choices: comic.choices,
          correctChoiceId: comic.choices
              .firstWhere((c) => c.id != comic.correctChoiceId)
              .id,
          facts: comic.facts,
          imageUrl: comic.imageUrl,
        );
        expect(await _verify(truth, features), isNotNull);
      });

      test('T-0060-AC4 seed $seed: a served round is made of bank '
          'questions', () async {
        final dio = jsonDio(triviaBackend(seed: seed));
        final byId = {for (final q in bank) q.id: q};
        for (var s = 0; s < 30; s++) {
          final round = await fetchRound(
            dio,
            category: ['all', ...categoryIds][s % 4],
            difficulty: difficulties[s % 3],
            seed: s,
          );
          for (final served in questionsOf(round)) {
            final q = byId[served['id']]!;
            expect(served['prompt'], q.prompt);
            expect(served['correctChoiceId'], q.correctChoiceId);
            expect(served['imageUrl'], q.imageUrl);
            expect(
              {
                for (final c in choicesOf(served)) c['id']: c['text'],
              },
              {
                for (final c in q.choices) c.id: c.text,
              },
            );
          }
        }
      });
    });
  }

  group('T-0060-AC4 images resolve to bundled assets', () {
    const resolver = BundledImageResolver();

    void expectBundled(String path, String reason) {
      final bundled = resolver.locate(ApiImage(path: path));
      for (final file in bundled.allDensityPaths) {
        expect(
          File('${media.path}/$file').existsSync(),
          isTrue,
          reason: '$reason -> $file',
        );
      }
    }

    test(
      'T-0060-AC4: every question image and category image resolves',
      () async {
        final seen = <String>{};
        for (final q in triviaQuestionBank(42)) {
          if (q.imageUrl != null) {
            expectBundled(q.imageUrl!, q.id);
            seen.add(q.imageUrl!);
          }
        }
        final categories =
            (await jsonDio(triviaBackend()).get<Json>('/v1/trivia/categories'))
                    .data!['categories']!
                as List;
        for (final c in categories.cast<Json>()) {
          expectBundled(c['imageUrl']! as String, 'category ${c['id']}');
          seen.add(c['imageUrl']! as String);
        }
        expect(seen.length, greaterThan(10));
      },
    );

    test('T-0060-AC4: the resolver rejects an image outside the set '
        '(negative control)', () {
      expect(
        () =>
            resolver.locate(const ApiImage(path: 'mock-asset://characters/24')),
        throwsA(isA<UnresolvedImageException>()),
      );
      expect(
        () => resolver.locate(const ApiImage(path: 'mock-asset://nowhere/001')),
        throwsA(isA<UnresolvedImageException>()),
      );
    });
  });

  group('T-0060-AC4 categories', () {
    test('T-0060-AC4: the categories list their question counts', () async {
      final dio = jsonDio(triviaBackend());
      final response = await call<Json>(dio, 'GET', '/v1/trivia/categories');
      final categories = (response.data!['categories']! as List).cast<Json>();
      expect(
        [for (final c in categories) c['id']],
        [
          'all',
          'characters',
          'comics',
          'creators',
        ],
      );
      final bank = triviaQuestionBank(42);
      for (final c in categories) {
        expect(c['name'], isA<String>());
        expect(
          c['questionCount'],
          c['id'] == 'all'
              ? bank.length
              : bank.where((q) => q.category == c['id']).length,
          reason: '${c['id']}',
        );
      }
      expect(
        [for (final c in categories) c['questionCount']],
        [336, 120, 144, 72],
      );
    });

    test('T-0060-AC4: the bank has the shape the contract states', () {
      final bank = triviaQuestionBank(42);
      final cells = <String, int>{};
      for (final q in bank) {
        final key = '${q.category}/${q.difficulty}';
        cells[key] = (cells[key] ?? 0) + 1;
        expect(q.id, matches(RegExp(r'^q-[a-z_]+-\d\d$')));
      }
      expect(cells, {
        'characters/easy': 24,
        'characters/medium': 48,
        'characters/hard': 48,
        'comics/easy': 48,
        'comics/medium': 48,
        'comics/hard': 48,
        'creators/easy': 24,
        'creators/medium': 24,
        'creators/hard': 24,
      });
    });
  });
}
