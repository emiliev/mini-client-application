import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';

/// The package directory in the test's runfiles (Bazel) or the checkout.
Directory _packageDir() {
  final srcDir = Platform.environment['TEST_SRCDIR'];
  final workspace = Platform.environment['TEST_WORKSPACE'] ?? '_main';
  for (final candidate in [
    if (srcDir != null) '$srcDir/$workspace/utility/mc_fixtures_media',
    'utility/mc_fixtures_media',
    '.',
  ]) {
    if (Directory('$candidate/assets/characters').existsSync()) {
      return Directory(candidate);
    }
  }
  throw StateError(
    'mc_fixtures_media assets not found from ${Directory.current}',
  );
}

void main() {
  const resolver = BundledImageResolver();

  group('T-0018-AC7 image resolution', () {
    test('T-0018-AC7: every placeholder id resolves to files that exist', () {
      final dir = _packageDir();
      for (final entry in placeholderSets.entries) {
        for (var i = 0; i < entry.value; i++) {
          final image = ApiImage(path: 'mock-asset://${entry.key}/$i');
          final bundled = resolver.resolve(image);
          for (final path in bundled.allDensityPaths) {
            final file = File('${dir.path}/$path');
            expect(file.existsSync(), isTrue, reason: '$image -> $path');
            expect(file.lengthSync(), lessThan(8 * 1024), reason: path);
          }
        }
      }
    });

    test('T-0018-AC7: path and variant resolve to a package asset key', () {
      final bundled = resolver.resolve(
        const ApiImage(
          path: 'mock-asset://characters/017',
          variant: ImageVariant.portraitLarge,
        ),
      );
      expect(
        bundled.assetKey,
        'packages/mc_fixtures_media/assets/characters/017.png',
      );
      expect(bundled.variant, ImageVariant.portraitLarge);
      expect(
        resolver.resolve(const ApiImage(path: 'mock-asset://characters/7')).id,
        '007',
      );
    });

    test('T-0018-AC7: unknown sets, ids and schemes are rejected', () {
      for (final path in [
        'mock-asset://covers/001',
        'mock-asset://characters/24',
        'mock-asset://characters/-1',
        'mock-asset://characters/abc',
        'https://example.invalid/a.png',
      ]) {
        expect(
          () => resolver.resolve(ApiImage(path: path)),
          throwsA(isA<UnresolvedImageException>()),
          reason: path,
        );
      }
      expect(
        resolver.canResolve(
          const ApiImage(path: 'https://example.invalid/a.png'),
        ),
        isFalse,
      );
    });

    test('T-0018-AC7: ApiImage JSON round-trips', () {
      const image = ApiImage(
        path: 'mock-asset://characters/003',
        variant: ImageVariant.landscape,
      );
      expect(ApiImage.fromJson(image.toJson()), image);
      expect(
        () => ApiImage.fromJson({'path': 'x', 'variant': 'huge'}),
        throwsFormatException,
      );
    });
  });
}
