import 'dart:convert';
import 'dart:io';

import 'package:mc_fixtures_platform/mc_fixtures_platform.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:test/test.dart';

import 'snapshot_cases.dart';

/// The package directory in the test's runfiles (Bazel) or the checkout.
Directory _dir(String relative) {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null) '$srcDir/$workspace/$relative',
    relative,
    '.',
  ]) {
    if (Directory(candidate).existsSync() &&
        File('$candidate/CONTRACT.md').existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError('$relative not found from ${Directory.current}');
}

void main() {
  final platform = _dir('utility/mc_fixtures_platform');

  group('T-0052-AC4 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0052-AC4: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${platform.path}/test/contract/snapshots/${entry.key}.json',
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

    test('T-0052-AC4: no snapshot file lacks a case', () {
      final files = Directory('${platform.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test('T-0052-AC4: a snapshot that no longer matches is detected '
        '(negative control)', () async {
      final expected = jsonDecode(
        File(
          '${platform.path}/test/contract/snapshots/flags_anonymous.json',
        ).readAsStringSync(),
      ) as Map<String, Object?>;
      final drifted = {...expected, 'status': 201};
      final actual = await runSnapshotCase(snapshotCases['flags_anonymous']!);
      expect(canonicalJson(actual), isNot(canonicalJson(drifted)));
      expect(canonicalJson(actual), canonicalJson(expected));
    });

    test(
      'T-0052-AC4: the route manifest, the domain, the scenarios and the '
      'sets agree',
      () {
        final manifest = jsonDecode(
          File(
            '${platform.path}/fixtures/routes.json',
          ).readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const PlatformMockDomain()]);
        expect([
          for (final r in backend.router.routes) r.key,
        ], manifest['routes']);
        expect(PlatformMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
        expect(platformFixtureSets.keys.toList()..sort(), manifest['sets']);
      },
    );

    test('T-0052-AC4: CONTRACT.md documents the route, every scenario, set '
        'and error code', () {
      final doc = File('${platform.path}/CONTRACT.md').readAsStringSync();
      expect(doc, contains('GET /v1/flags'));
      for (final name in const [
        'platform.empty',
        'platform.flags_malformed',
        'platform.server_error',
      ]) {
        expect(doc, contains('`$name`'));
      }
      for (final set in platformFixtureSets.keys) {
        expect(doc, contains('`$set`'));
      }
      expect(doc, contains('`injected_failure`'));
      for (final key in flagsForUser(null).keys) {
        expect(doc, contains('`$key`'));
      }
      for (final experiment in const ['store_home_layout', 'trivia_hint']) {
        expect(doc, contains('`$experiment`'));
      }
    });
  });
}
