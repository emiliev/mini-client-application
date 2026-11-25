// Verifier probe (T-0031), kept as evidence. To re-run, copy into the package test/ dir with a flutter_test target (deps = _TEST_DEPS).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

class _MissingKeyResolver implements McImageResolver {
  @override
  bool canResolve(ApiImage image) => true;

  @override
  ResolvedImage resolve(ApiImage image) => const ResolvedImage.asset(
    'assets/characters/does_not_exist.png',
    package: 'mc_fixtures_media',
  );
}

class _NetworkResolver implements McImageResolver {
  @override
  bool canResolve(ApiImage image) => true;

  @override
  ResolvedImage resolve(ApiImage image) =>
      ResolvedImage.network(Uri.parse(image.path));
}

void main() {
  testWidgets('PROBE a missing asset key shows the fallback', (t) async {
    await t.pumpWidget(
      mcGoldenApp(
        bundle: McFixtureAssetBundle(),
        child: McMediaScope(
          resolver: _MissingKeyResolver(),
          child: const SizedBox(
            width: 100,
            child: McImage(image: ApiImage(path: 'mock-asset://x/1')),
          ),
        ),
      ),
    );
    await t.pump();
    for (
      var i = 0;
      i < 200 && find.byKey(McImage.fallbackKey).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    expect(find.byKey(McImage.fallbackKey), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('PROBE McImage builds a NetworkImage for a network case', (
    t,
  ) async {
    await t.pumpWidget(
      mcGoldenApp(
        child: McMediaScope(
          resolver: _NetworkResolver(),
          child: const SizedBox(
            width: 100,
            child: McImage(image: ApiImage(path: 'https://x.test/a.png')),
          ),
        ),
      ),
    );
    final image = t.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, 'https://x.test/a.png');
    // Let the (failing, no network in tests) load settle into the fallback.
    for (
      var i = 0;
      i < 200 && find.byKey(McImage.fallbackKey).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump();
    }
    print(
      'PROBE network fallback shown: '
      '${find.byKey(McImage.fallbackKey).evaluate().isNotEmpty}',
    );
    t.takeException();
  });
}
