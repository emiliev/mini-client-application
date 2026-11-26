import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
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

ApiImage _image(Object? json) {
  final map = json! as Map<String, Object?>;
  return ApiImage(
    path: map['path']! as String,
    variant: ImageVariant.fromWire(map['variant']! as String),
  );
}

void main() {
  final library = _dir('utility/mc_fixtures_library');
  final media = _dir('utility/mc_fixtures_media');

  group('T-0047-AC4 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0047-AC4: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${library.path}/test/contract/snapshots/${entry.key}.json',
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

    test('T-0047-AC4: no snapshot file lacks a case', () {
      final files = Directory('${library.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test('T-0047-AC4: every route and every error code has a snapshot', () {
      final requests = [
        for (final c in snapshotCases.values) '${c.method} ${c.path}',
      ];
      for (final route in libraryRouteManifest) {
        final method = route.split(' ').first;
        final pattern = RegExp(
          '^$method ${route.split(' ').last.replaceAll(':id', r'l-\d+')}\$',
        );
        expect(requests.any(pattern.hasMatch), isTrue, reason: route);
      }
    });

    test(
      'T-0047-AC4: the route manifest, the domain and the scenarios agree',
      () {
        final manifest = jsonDecode(
          File(
            '${library.path}/fixtures/routes.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const LibraryMockDomain()]);
        expect([
          for (final r in backend.router.routes) r.key,
        ], manifest['routes']);
        expect(LibraryMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
      },
    );

    test('T-0047-AC4: CONTRACT.md documents every route, scenario, set and '
        'error code', () {
      final doc = File('${library.path}/CONTRACT.md').readAsStringSync();
      for (final route in LibraryMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final scenario in const ['library.empty', 'library.server_error']) {
        expect(doc, contains(scenario));
      }
      for (final set in libraryFixtureSets.keys) {
        expect(doc, contains('`$set`'));
      }
      for (final code in const [
        'unauthenticated',
        'list_not_found',
        'invalid_name',
        'invalid_description',
        'invalid_visibility',
        'invalid_body',
        'too_many_comics',
        'duplicate_comic',
        'unknown_comic',
        'injected_failure',
      ]) {
        expect(doc, contains('`$code`'), reason: code);
      }
    });
  });

  group('T-0047-AC4 links to the comics domain', () {
    for (final seed in [42, 7]) {
      test('T-0047-AC4 seed $seed: every item id resolves on GET '
          '/v1/comics/{id}, with the same title and cover', () async {
        final backend = MockBackend(
          seed: seed,
          domains: [const LibraryMockDomain(), const ComicsMockDomain()],
        );
        final dio = jsonDio(backend);
        // Seeded lists and a list holding a spread of the catalogue.
        final ids = [
          for (var i = 0; i < 100; i++) ComicUniverse(seed).byTitle[i * 23].id,
        ];
        await call<Object?>(
          dio,
          'POST',
          '/v1/me/lists',
          body: {'name': 'Spread', 'visibility': 'private', 'comicIds': ids},
          headers: bearer(reader),
        );
        var checked = 0;
        for (final user in [reader, collector]) {
          final lists =
              (await call<Map<String, Object?>>(
                    dio,
                    'GET',
                    '/v1/me/lists',
                    headers: bearer(user),
                  )).data!['lists']!
                  as List;
          for (final l in lists.cast<Map<String, Object?>>()) {
            final detail = (await call<Map<String, Object?>>(
              dio,
              'GET',
              '/v1/me/lists/${l['id']}',
              headers: bearer(user),
            )).data!;
            for (final item
                in (detail['items']! as List).cast<Map<String, Object?>>()) {
              final comic = (await call<Map<String, Object?>>(
                dio,
                'GET',
                '/v1/comics/${item['id']}',
              )).data!;
              expect(comic['id'], item['id'], reason: '$item');
              expect(comic['title'], item['title'], reason: '$item');
              expect(comic['cover'], item['thumbnail'], reason: '$item');
              checked++;
            }
          }
        }
        expect(checked, greaterThan(100));
      });
    }

    test('T-0047-AC4: every thumbnail resolves to a bundled asset', () async {
      final backend = MockBackend(domains: [const LibraryMockDomain()]);
      final dio = jsonDio(backend);
      final ids = [for (final c in ComicUniverse(42).byTitle.take(100)) c.id];
      final created = (await call<Map<String, Object?>>(
        dio,
        'POST',
        '/v1/me/lists',
        body: {'name': 'All', 'visibility': 'private', 'comicIds': ids},
        headers: bearer(reader),
      )).data!;
      const resolver = BundledImageResolver();
      final seen = <String>{};
      for (final item
          in (created['items']! as List).cast<Map<String, Object?>>()) {
        final bundled = resolver.locate(_image(item['thumbnail']));
        for (final path in bundled.allDensityPaths) {
          seen.add(path);
          expect(
            File('${media.path}/$path').existsSync(),
            isTrue,
            reason: '$item -> $path',
          );
        }
      }
      expect(seen.length, greaterThan(24));
    });

    for (final seed in [42, 7]) {
      test('T-0047-AC4 seed $seed: the library.empty scenario answers what '
          'the empty set answers, with the comics endpoint\'s titles and '
          'covers', () async {
        final scenario = MockBackend(
          seed: seed,
          domains: [const LibraryMockDomain(), const ComicsMockDomain()],
        )..useScenario('library.empty');
        final set = MockBackend(
          seed: seed,
          domains: [const EmptyLibraryDomain(), const ComicsMockDomain()],
        );
        final ids = [
          for (var i = 0; i < 40; i++) ComicUniverse(seed).byTitle[i * 37].id,
        ];
        Future<Map<String, Object?>> create(MockBackend b) async =>
            (await call<Map<String, Object?>>(
              jsonDio(b),
              'POST',
              '/v1/me/lists',
              body: {'name': 'E', 'visibility': 'private', 'comicIds': ids},
              headers: bearer(reader),
            )).data!;
        final fromScenario = await create(scenario);
        expect(canonicalJson(fromScenario), canonicalJson(await create(set)));
        final comics = jsonDio(scenario);
        for (final item
            in (fromScenario['items']! as List).cast<Map<String, Object?>>()) {
          final comic = (await call<Map<String, Object?>>(
            comics,
            'GET',
            '/v1/comics/${item['id']}',
          )).data!;
          expect(item['title'], comic['title'], reason: '$item');
          expect(item['thumbnail'], comic['cover'], reason: '$item');
        }
      });
    }

    test('T-0047-AC4: the resolver rejects a thumbnail outside the set '
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
