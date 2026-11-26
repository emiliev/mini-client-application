import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
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

void _collectImages(Object? node, List<ApiImage> out) {
  if (node is Map) {
    if (node case {'path': final String path, 'variant': final String variant}
        when path.contains('://')) {
      out.add(ApiImage(path: path, variant: ImageVariant.fromWire(variant)));
    }
    node.values.forEach((v) => _collectImages(v, out));
  } else if (node is List) {
    node.forEach((v) => _collectImages(v, out));
  }
}

void main() {
  final comics = _dir('utility/mc_fixtures_comics');
  final media = _dir('utility/mc_fixtures_media');

  group('T-0038-AC3 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0038-AC3: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${comics.path}/test/contract/snapshots/${entry.key}.json',
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

    test('T-0038-AC3: no snapshot file lacks a case', () {
      final files = Directory('${comics.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test(
      'T-0038-AC3: the route manifest, the domain and the scenarios agree',
      () {
        final manifest = jsonDecode(
          File('${comics.path}/fixtures/routes.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const ComicsMockDomain()]);
        expect([
          for (final r in backend.router.routes) r.key,
        ], manifest['routes']);
        expect(ComicsMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
      },
    );

    test('T-0038-AC3: CONTRACT.md documents every route, scenario and set', () {
      final doc = File('${comics.path}/CONTRACT.md').readAsStringSync();
      for (final route in ComicsMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final scenario in const ['comics.empty', 'comics.server_error']) {
        expect(doc, contains(scenario));
      }
      for (final set in comicsFixtureSets.keys) {
        expect(doc, contains('`$set`'));
      }
    });

    test('T-0038-AC3: the documented counts equal the real ones', () async {
      final doc = File('${comics.path}/CONTRACT.md').readAsStringSync();
      final spi = int.parse(
        RegExp(r'titleStartsWith=spi`.*?\((\d+) comics\)')
            .firstMatch(doc)!
            .group(1)!,
      );
      final page = await snapshotBackend()
          .createDio()
          .get<Map<String, Object?>>(
            '/v1/comics',
            queryParameters: {'titleStartsWith': 'spi', 'limit': 1},
          );
      expect(page.data!['total'], spi);
      final total = int.parse(
        RegExp(r'\| Comics \| ([\d,]+)')
            .firstMatch(doc)!
            .group(1)!
            .replaceAll(',', ''),
      );
      expect(total, seriesCount * issuesPerSeries);
    });
  });

  group('T-0038-AC3 links to the other fixture domains', () {
    test('T-0038-AC3: the ID contract constants match the real packages', () {
      final characters = CharacterUniverse(42, defaultMockClock).byName;
      final ids = [for (final c in characters) c.id]..sort();
      expect(ids.first, characterIdBase);
      expect(ids.last, characterIdBase + characterIdCount - 1);
      expect(ids, hasLength(characterIdCount));
      expect(characterIdCount, characterCount);
      expect(placeholderSets[coverImageSet], coverImageCount);
    });

    test('T-0038-AC3: every characterId a comic references resolves', () {
      final known = {
        for (final c in CharacterUniverse(42, defaultMockClock).byName) c.id,
      };
      var links = 0;
      for (final comic in ComicUniverse(42).byTitle) {
        expect(comic.characterIds, isNotEmpty, reason: comic.title);
        for (final id in comic.characterIds) {
          links++;
          expect(known, contains(id), reason: '${comic.title} -> $id');
        }
      }
      expect(links, greaterThan(5000));
    });

    test('T-0038-AC3: a seed other than 42 still links to real characters', () {
      final known = {
        for (final c in CharacterUniverse(7, defaultMockClock).byName) c.id,
      };
      for (final comic in ComicUniverse(7).byTitle) {
        expect(known.containsAll(comic.characterIds), isTrue);
      }
    });

    test(
      'T-0038-AC3: a characterId filter finds a real character\'s comics',
      () async {
        // 100000 is linked from six comics (CONTRACT.md); a character with no
        // comics would make this test pass without checking anything.
        const characterId = 100000;
        final expected = {
          for (final c in ComicUniverse(42).byTitle)
            if (c.characterIds.contains(characterId)) c.id,
        };
        expect(expected, hasLength(6));
        final dio = MockBackend(
          domains: [const ComicsMockDomain(), const CharactersMockDomain()],
        ).createDio();
        final page = await dio.get<Map<String, Object?>>(
          '/v1/comics',
          queryParameters: {'characterId': characterId, 'limit': 100},
        );
        final detail = await dio.get<Map<String, Object?>>(
          '/v1/characters/$characterId',
        );
        expect(detail.data!['id'], characterId);
        expect(page.data!['total'], greaterThan(0));
        expect(page.data!['total'], expected.length);
        final results = (page.data!['results']! as List)
            .cast<Map<String, Object?>>();
        expect({for (final c in results) c['id']}, expected);
        for (final c in results) {
          final comic = await dio.get<Map<String, Object?>>(
            '/v1/comics/${c['id']}',
          );
          expect(comic.data!['characterIds'], contains(characterId));
        }
      },
    );
  });

  group('T-0038-AC3 images in responses', () {
    test('T-0038-AC3: every cover ApiImage in all responses resolves to an existing asset', () async {
      final dio = MockBackend(domains: [const ComicsMockDomain()]).createDio();
      const resolver = BundledImageResolver();
      final images = <ApiImage>[];
      for (var offset = 0; offset < 2400; offset += 100) {
        final page = await dio.get<Object?>(
          '/v1/comics',
          queryParameters: {'offset': offset, 'limit': 100},
        );
        _collectImages(page.data, images);
      }
      final listCovers = images.length;
      for (final comic in ComicUniverse(42).byTitle) {
        final detail = await dio.get<Object?>('/v1/comics/${comic.id}');
        _collectImages(detail.data, images);
      }
      for (var s = 0; s < seriesCount; s++) {
        final series = await dio.get<Object?>('/v1/series/${400000 + s}');
        _collectImages(series.data, images);
      }
      expect(listCovers, 2400);
      expect(images.length, greaterThan(2400 * 2 + seriesCount));

      final seen = <String>{};
      for (final image in images) {
        final bundled = resolver.locate(image);
        for (final path in bundled.allDensityPaths) {
          if (!seen.add(path)) {
            continue;
          }
          expect(
            File('${media.path}/$path').existsSync(),
            isTrue,
            reason: '$image -> $path',
          );
        }
      }
      expect(seen.length, greaterThan(24));
    });

    test('T-0038-AC3: the resolver rejects a cover outside the set (negative control)', () {
      const resolver = BundledImageResolver();
      expect(
        () => resolver.locate(
          ApiImage(path: 'mock-asset://$coverImageSet/$coverImageCount'),
        ),
        throwsA(isA<UnresolvedImageException>()),
      );
    });
  });

  group('T-0038-AC3 vocabulary', () {
    test('T-0038-AC3: no series title uses a trademarked single word', () {
      final titles = {for (final s in ComicUniverse(42).allSeries) s.title};
      expect(titles, hasLength(seriesCount));
      for (final banned in const ['Gambit', 'Iron']) {
        expect(
          titles.where((t) => t.contains(banned)),
          isEmpty,
          reason: banned,
        );
      }
    });

    test('T-0038-AC3: the whole creator pool is reachable, all 10 surnames', () {
      final names = <String>{};
      for (final c in ComicUniverse(42).byTitle) {
        for (final credit in c.creators) {
          names.add(credit.name);
        }
      }
      expect(names, hasLength(creatorCount));
      expect({for (final n in names) n.split(' ').last}, hasLength(10));
    });
  });
}
