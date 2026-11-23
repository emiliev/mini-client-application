import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
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
    if (Directory(candidate).existsSync()) return Directory(candidate);
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
  final characters = _dir('utility/mc_fixtures_characters');
  final media = _dir('utility/mc_fixtures_media');

  group('T-0018-AC7 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0018-AC7: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${characters.path}/test/contract/snapshots/${entry.key}.json',
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

    test('T-0018-AC7: no snapshot file lacks a case', () {
      final files = Directory('${characters.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test(
      'T-0018-AC7: the route manifest, the domain and the scenarios agree',
      () {
        final manifest = jsonDecode(
          File('${characters.path}/fixtures/routes.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const CharactersMockDomain()]);
        expect(
          [for (final r in backend.router.routes) r.key],
          manifest['routes'],
        );
        expect(CharactersMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
      },
    );

    test(
      'T-0018-AC7: the documented nameStartsWith=spi count equals the real one',
      () async {
        final doc = File('${characters.path}/CONTRACT.md').readAsStringSync();
        final documented = int.parse(
          RegExp(r'nameStartsWith=spi`.*?\((\d+) characters\)')
              .firstMatch(doc)!
              .group(1)!,
        );
        final page = await snapshotBackend()
            .createDio()
            .get<Map<String, Object?>>(
              '/v1/characters',
              queryParameters: {'nameStartsWith': 'spi', 'limit': 1},
            );
        expect(page.data!['total'], documented);
      },
    );

    test('T-0018-AC7: CONTRACT.md documents every route and scenario', () {
      final doc = File('${characters.path}/CONTRACT.md').readAsStringSync();
      for (final route in CharactersMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final scenario in const [
        'characters.empty',
        'characters.server_error',
      ]) {
        expect(doc, contains(scenario));
      }
    });
  });

  group('T-0018-AC7 images in responses', () {
    test('T-0018-AC7: every ApiImage in all 1,500 responses resolves to an existing asset', () async {
      final dio = MockBackend(domains: [const CharactersMockDomain()])
          .createDio();
      const resolver = BundledImageResolver();
      final images = <ApiImage>[];
      for (var offset = 0; offset < 1500; offset += 100) {
        final page = await dio.get<Object?>(
          '/v1/characters',
          queryParameters: {'offset': offset, 'limit': 100},
        );
        _collectImages(page.data, images);
      }
      final detail = await dio.get<Object?>('/v1/characters/100000');
      _collectImages(detail.data, images);
      expect(images, hasLength(1501));

      final seen = <String>{};
      for (final image in images) {
        final bundled = resolver.resolve(image);
        for (final path in bundled.allDensityPaths) {
          if (!seen.add(path)) continue;
          expect(
            File('${media.path}/$path').existsSync(),
            isTrue,
            reason: '$image -> $path',
          );
        }
      }
      expect(seen.length, greaterThan(24));
    });
  });
}
