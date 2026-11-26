import 'dart:convert';
import 'dart:io';

import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
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
  final identity = _dir('utility/mc_fixtures_identity');

  group('T-0039-AC3 provider contract snapshots', () {
    for (final entry in snapshotCases.entries) {
      test('T-0039-AC3: ${entry.key} matches its snapshot', () async {
        final file = File(
          '${identity.path}/test/contract/snapshots/${entry.key}.json',
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

    test('T-0039-AC3: no snapshot file lacks a case', () {
      final files = Directory('${identity.path}/test/contract/snapshots')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, {for (final k in snapshotCases.keys) '$k.json'});
    });

    test(
      'T-0039-AC3: the route manifest, the domain and the scenarios agree',
      () {
        final manifest = jsonDecode(
          File('${identity.path}/fixtures/routes.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final backend = MockBackend(domains: [const IdentityMockDomain()]);
        expect([
          for (final r in backend.router.routes) r.key,
        ], manifest['routes']);
        expect(IdentityMockDomain.routeManifest, manifest['routes']);
        expect(backend.scenarioNames.toList()..sort(), manifest['scenarios']);
        expect(identityFixtureSets.keys, manifest['sets']);
      },
    );

    test('T-0039-AC3: CONTRACT.md documents every route, scenario and set', () {
      final doc = File('${identity.path}/CONTRACT.md').readAsStringSync();
      for (final route in IdentityMockDomain.routeManifest) {
        expect(doc, contains(route));
      }
      for (final name in [
        'identity.expired_token',
        'identity.server_error',
        ...identityFixtureSets.keys,
      ]) {
        expect(doc, contains(name));
      }
      for (final user in fixtureUsers) {
        expect(doc, contains(user.email));
        expect(doc, contains(user.password));
      }
    });
  });
}
