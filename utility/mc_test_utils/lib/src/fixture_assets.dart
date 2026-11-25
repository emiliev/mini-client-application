/// Serves the bundled fixture art (`mc_fixtures_media`) to widget tests.
///
/// The widget tester has no asset bundle of its own under Bazel. This bundle
/// reads the PNGs from the runfiles (`data = [fixtures asset_files]`) or from
/// a checkout, so goldens draw the real art (T-0031).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bazel `data` label a test that draws fixture art must list.
const String mcFixtureAssetsDataLabel =
    '//utility/mc_fixtures_media:asset_files';

const _prefix = 'packages/mc_fixtures_media/';

Directory _fixturesDir() {
  final env = Platform.environment;
  final src = env['TEST_SRCDIR'];
  final workspace = env['TEST_WORKSPACE'] ?? '_main';
  final candidates = [
    if (src != null) '$src/$workspace/utility/mc_fixtures_media',
    'utility/mc_fixtures_media',
    '../mc_fixtures_media',
  ];
  for (final c in candidates) {
    if (Directory('$c/assets').existsSync()) {
      return Directory(c);
    }
  }
  throw StateError(
    'mc_fixtures_media assets not found. Tried: $candidates (cwd '
    '${Directory.current.path}). Add $mcFixtureAssetsDataLabel to the test '
    'target `data`.',
  );
}

/// An [AssetBundle] over the `mc_fixtures_media` files.
///
/// Every load waits for [gate] when one is given, so a test can show the
/// placeholder, then complete the gate to let the image arrive. Loads of a
/// key under [failingKeys] throw, for the fallback state.
class McFixtureAssetBundle extends CachingAssetBundle {
  McFixtureAssetBundle({this.gate, this.failingKeys = const {}});

  /// Loads complete when this does. Null: they complete at once.
  final Future<void>? gate;
  final Set<String> failingKeys;

  /// How many `load` calls reached a fixture file.
  int fileLoads = 0;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      // No density variants: every asset is its own 1x file.
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    await gate;
    if (failingKeys.contains(key) || !key.startsWith(_prefix)) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    final file = File(
      '${_fixturesDir().path}/${key.substring(_prefix.length)}',
    );
    if (!file.existsSync()) {
      throw FlutterError('Unable to load asset: "$key" (no such file).');
    }
    fileLoads++;
    return ByteData.sublistView(file.readAsBytesSync());
  }
}

/// Decodes [assetKeys] from [bundle] into the image cache before the widgets
/// under test are pumped, so the first frame draws them. Real async work, so
/// it runs outside the fake clock.
Future<void> mcPrecacheFixtureImages(
  WidgetTester tester,
  AssetBundle bundle,
  Iterable<String> assetKeys,
) async {
  await tester.runAsync(() async {
    for (final key in assetKeys) {
      final done = Completer<void>();
      final stream = AssetImage(key, bundle: bundle).resolve(
        const ImageConfiguration(),
      );
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, sync) => done.complete(),
        onError: (error, stack) => done.completeError(error, stack),
      );
      stream.addListener(listener);
      try {
        await done.future;
      } finally {
        stream.removeListener(listener);
      }
    }
  });
}
