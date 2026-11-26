import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';

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

/// Every search result of [queries] (all groups, up to 100 each).
Future<List<Map<String, Object?>>> _results(
  Dio dio,
  List<String> queries,
) async {
  final out = <Map<String, Object?>>[];
  for (final q in queries) {
    final body = (await dio.get<Map<String, Object?>>(
      '/v1/search',
      queryParameters: {'q': q, 'limit': 100},
    )).data!;
    for (final group
        in (body['groups']! as List).cast<Map<String, Object?>>()) {
      out.addAll((group['results']! as List).cast<Map<String, Object?>>());
    }
  }
  return out;
}

ApiImage _image(Object? json) {
  final map = json! as Map<String, Object?>;
  return ApiImage(
    path: map['path']! as String,
    variant: ImageVariant.fromWire(map['variant']! as String),
  );
}

const _queries = ['spi', 'co', 'amber', 'chron', 'war', 'ber', 'ar', 'st'];

void main() {
  final discovery = _dir('utility/mc_fixtures_discovery');
  final media = _dir('utility/mc_fixtures_media');

  group('T-0043-AC3 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0043-AC3: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${discovery.path}/test/contract/snapshots/${entry.key}.json',
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

    test('T-0043-AC3: no snapshot file lacks a case', () {
      final files = Directory('${discovery.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test(
      'T-0043-AC3: the route manifest, the domain and the scenarios agree',
      () {
        final manifest = jsonDecode(
          File('${discovery.path}/fixtures/routes.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const DiscoveryMockDomain()]);
        expect([
          for (final r in backend.router.routes) r.key,
        ], manifest['routes']);
        expect(DiscoveryMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
      },
    );

    test('T-0043-AC3: CONTRACT.md documents every route, scenario and set', () {
      final doc = File('${discovery.path}/CONTRACT.md').readAsStringSync();
      for (final route in DiscoveryMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final scenario in const [
        'discovery.empty',
        'discovery.server_error',
      ]) {
        expect(doc, contains(scenario));
      }
      for (final set in discoveryFixtureSets.keys) {
        expect(doc, contains('`$set`'));
      }
      for (final code in const [
        'query_too_short',
        'invalid_parameter',
        'injected_failure',
      ]) {
        expect(doc, contains(code));
      }
    });

    test('T-0043-AC3: the documented counts equal the real ones', () async {
      final doc = File('${discovery.path}/CONTRACT.md').readAsStringSync();
      final match = RegExp(
        r'`q=spi`.*?\((\d+) characters and (\d+) comics\)',
      ).firstMatch(doc)!;
      final body =
          (await snapshotBackend().createDio().get<Map<String, Object?>>(
            '/v1/search',
            queryParameters: {'q': 'spi', 'limit': 1},
          )).data!;
      final totals = [
        for (final g in (body['groups']! as List).cast<Map<String, Object?>>())
          g['total'],
      ];
      expect(totals, [int.parse(match.group(1)!), int.parse(match.group(2)!)]);
    });
  });

  group('T-0043-AC3 links to the other fixture domains', () {
    for (final seed in [42, 7]) {
      test('T-0043-AC3 seed $seed: every result id resolves on its own '
          "domain's detail endpoint, with the same title and image", () async {
        final dio = MockBackend(
          seed: seed,
          domains: [
            const DiscoveryMockDomain(),
            const CharactersMockDomain(),
            const ComicsMockDomain(),
          ],
        ).createDio();
        final results = await _results(dio, _queries);
        final types = <String, int>{};
        for (final r in results) {
          final type = r['type']! as String;
          types.update(type, (n) => n + 1, ifAbsent: () => 1);
          final detail = (await dio.get<Map<String, Object?>>(
            '/v1/${type == 'character' ? 'characters' : 'comics'}/${r['id']}',
          )).data!;
          expect(detail['id'], r['id'], reason: '$r');
          expect(
            detail[type == 'character' ? 'name' : 'title'],
            r['title'],
            reason: '$r',
          );
          expect(
            detail[type == 'character' ? 'thumbnail' : 'cover'],
            r['thumbnail'],
            reason: '$r',
          );
        }
        expect(types['character'], greaterThan(500));
        expect(types['comic'], greaterThan(500));
      });
    }

    test('T-0043-AC3: the index covers every character and comic exactly '
        'once, by its exact title', () async {
      final dio = MockBackend(domains: [const DiscoveryMockDomain()])
          .createDio();
      final expected = <(String, int)>[
        for (final c in CharacterUniverse(42, defaultMockClock).byName)
          ('character', c.id),
        for (final c in ComicUniverse(42).byTitle) ('comic', c.id),
      ];
      expect(expected, hasLength(characterCount + 2400));
      final titles = <String, String>{
        for (final c in CharacterUniverse(42, defaultMockClock).byName)
          'character:${c.id}': c.name,
        for (final c in ComicUniverse(42).byTitle) 'comic:${c.id}': c.title,
      };
      for (final (type, id) in expected) {
        final body = (await dio.get<Map<String, Object?>>(
          '/v1/search',
          queryParameters: {'q': titles['$type:$id'], 'types': type},
        )).data!;
        final first =
            ((body['groups']! as List).single as Map)['results'] as List;
        expect((first.first as Map)['id'], id, reason: titles['$type:$id']);
      }
    });

    test('T-0043-AC3: no title is shared between two ids of one type', () {
      final names = [
        for (final c in CharacterUniverse(42, defaultMockClock).byName) c.name,
      ];
      final titles = [for (final c in ComicUniverse(42).byTitle) c.title];
      expect(names.toSet(), hasLength(names.length));
      expect(titles.toSet(), hasLength(titles.length));
    });
  });

  group('T-0043-AC3 images in responses', () {
    test('T-0043-AC3: every thumbnail in the results resolves to an existing '
        'asset', () async {
      final dio = MockBackend(domains: [const DiscoveryMockDomain()])
          .createDio();
      const resolver = BundledImageResolver();
      final results = await _results(dio, _queries);
      expect(results.length, greaterThan(1000));
      final seen = <String>{};
      for (final r in results) {
        final bundled = resolver.locate(_image(r['thumbnail']));
        for (final path in bundled.allDensityPaths) {
          if (!seen.add(path)) {
            continue;
          }
          expect(
            File('${media.path}/$path').existsSync(),
            isTrue,
            reason: '$r -> $path',
          );
        }
      }
      expect(seen.length, greaterThan(24));
    });

    test('T-0043-AC3: the resolver rejects a thumbnail outside the set '
        '(negative control)', () {
      const resolver = BundledImageResolver();
      expect(
        () => resolver.locate(
          ApiImage(path: 'mock-asset://characters/$coverImageCount'),
        ),
        throwsA(isA<UnresolvedImageException>()),
      );
    });
  });
}
