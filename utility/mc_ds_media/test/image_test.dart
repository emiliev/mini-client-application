import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

const _art = 'packages/mc_fixtures_media/assets/characters/000.png';
const _good = ApiImage(path: 'mock-asset://characters/0');

class _ThrowingResolver implements McImageResolver {
  const _ThrowingResolver(this.error);

  final Object error;

  @override
  bool canResolve(ApiImage image) => true;

  @override
  ResolvedImage resolve(ApiImage image) => throw error;
}

Widget _app(
  Widget child, {
  McImageResolver resolver = const BundledImageResolver(),
  AssetBundle? bundle,
  bool disableAnimations = false,
}) {
  final scoped = McMediaScope(resolver: resolver, child: child);
  final body = disableAnimations
      ? Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: scoped,
          ),
        )
      : scoped;
  return mcGoldenApp(child: body, bundle: bundle);
}

/// Real async work (the engine decodes the picture) needs the real clock, so
/// advance both until [finder] matches. Bounded: it fails if the image never
/// arrives.
Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget, reason: 'the image never finished loading');
}

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
  });

  group('T-0031-AC3 McImage states', () {
    testWidgets(
      'T-0031-AC3: placeholder first, then the resolved bundled image',
      (tester) async {
        final gate = Completer<void>();
        final bundle = McFixtureAssetBundle(gate: gate.future);
        await tester.pumpWidget(
          _app(
            const SizedBox(width: 100, child: McImage(image: _good)),
            bundle: bundle,
          ),
        );
        await tester.pump();

        expect(find.byKey(McImage.placeholderKey), findsOneWidget);
        expect(find.byKey(McImage.loadedKey), findsNothing);
        expect(find.byKey(McImage.fallbackKey), findsNothing);
        expect(bundle.fileLoads, 0);

        gate.complete();
        await tester.pump();
        await _pumpUntilFound(tester, find.byKey(McImage.loadedKey));
        await tester.pump(const Duration(seconds: 1));

        expect(bundle.fileLoads, 1);
        expect(find.byKey(McImage.placeholderKey), findsNothing);
        expect(find.byKey(McImage.fallbackKey), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T-0031-AC3: a cached image shows at once, no placeholder', (
      tester,
    ) async {
      final bundle = McFixtureAssetBundle();
      await mcPrecacheFixtureImages(tester, bundle, [_art]);
      await tester.pumpWidget(
        _app(
          const SizedBox(width: 100, child: McImage(image: _good)),
          bundle: bundle,
        ),
      );

      expect(find.byKey(McImage.loadedKey), findsOneWidget);
      expect(find.byKey(McImage.placeholderKey), findsNothing);
    });

    testWidgets('T-0031-AC3: reduced motion skips the cross-fade', (
      tester,
    ) async {
      final bundle = McFixtureAssetBundle();
      await tester.pumpWidget(
        _app(
          const SizedBox(width: 100, child: McImage(image: _good)),
          bundle: bundle,
          disableAnimations: true,
        ),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.byKey(McImage.loadedKey));
      // No fade to wait for: the placeholder is already gone.
      expect(find.byKey(McImage.placeholderKey), findsNothing);
    });

    testWidgets(
      'T-0031-AC3: UnresolvedImageException shows the fallback and does not throw',
      (tester) async {
        for (final path in [
          'mock-asset://characters/999',
          'mock-asset://nowhere/1',
          'https://example.com/a.png',
        ]) {
          await tester.pumpWidget(
            _app(
              SizedBox(
                width: 100,
                child: McImage(image: ApiImage(path: path)),
              ),
              bundle: McFixtureAssetBundle(),
            ),
          );
          await tester.pump();
          expect(find.byKey(McImage.fallbackKey), findsOneWidget, reason: path);
          expect(find.byKey(McImage.placeholderKey), findsNothing);
          expect(tester.takeException(), isNull, reason: path);
        }
      },
    );

    testWidgets(
      'T-0031-AC3: a resolver that throws an Exception shows the fallback',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            const SizedBox(width: 100, child: McImage(image: _good)),
            resolver: const _ThrowingResolver(FormatException('bad')),
          ),
        );
        expect(find.byKey(McImage.fallbackKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('T-0031-AC3: an Error from a resolver is not swallowed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(width: 100, child: McImage(image: _good)),
          resolver: _ThrowingResolver(StateError('bug')),
        ),
      );
      expect(find.byKey(McImage.fallbackKey), findsNothing);
      expect(tester.takeException(), isA<StateError>());
    });

    test('T-0031-AC3: each ResolvedImage case maps to its ImageProvider', () {
      final asset = mcImageProviderFor(
        const ResolvedImage.asset('assets/a.png', package: 'p'),
      );
      expect(asset, isA<AssetImage>());
      expect((asset as AssetImage).keyName, 'packages/p/assets/a.png');

      final net = mcImageProviderFor(
        ResolvedImage.network(Uri.parse('https://x.test/a.png')),
      );
      expect(net, isA<NetworkImage>());
      expect((net as NetworkImage).url, 'https://x.test/a.png');
    });

    testWidgets('T-0031-AC3: a file that fails to load shows the fallback', (
      tester,
    ) async {
      final bundle = McFixtureAssetBundle(failingKeys: {_art});
      await tester.pumpWidget(
        _app(
          const SizedBox(width: 100, child: McImage(image: _good)),
          bundle: bundle,
        ),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.byKey(McImage.fallbackKey));
      expect(find.byKey(McImage.loadedKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0031-AC3: without a McMediaScope a FlutterError names it', (
      tester,
    ) async {
      await tester.pumpWidget(mcGoldenApp(child: const McImage(image: _good)));
      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('McMediaScope'));
    });
  });

  group('T-0031-AC5 McImage semantics and size', () {
    testWidgets('T-0031-AC5: an image without a label is not in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const SizedBox(width: 100, child: McImage(image: _good)),
          bundle: McFixtureAssetBundle(),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('T-0031-AC5: an image with a label announces it once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 100,
            child: McImage(image: _good, semanticLabel: 'Wiimm portrait'),
          ),
          bundle: McFixtureAssetBundle(),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Wiimm portrait'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('T-0031-AC3: the variant sets the aspect ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              SizedBox(
                width: 100,
                child: McImage(image: _good, variant: ImageVariant.landscape),
              ),
              SizedBox(width: 100, child: McImage(image: _good)),
            ],
          ),
          bundle: McFixtureAssetBundle(),
        ),
      );
      final sizes = tester
          .widgetList<McImage>(find.byType(McImage))
          .map((w) => tester.getSize(find.byWidget(w)))
          .toList();
      // landscape 175x100, default portraitMedium 100x150
      expect(sizes[0].height, closeTo(100 / 1.75, 0.01));
      expect(sizes[1].height, closeTo(150, 0.01));
    });

    testWidgets('T-0031-AC3: explicit width and height win', (tester) async {
      await tester.pumpWidget(
        _app(
          const McImage(image: _good, width: 30, height: 40),
          bundle: McFixtureAssetBundle(),
        ),
      );
      expect(tester.getSize(find.byType(McImage)), const Size(30, 40));
    });
  });

  group('T-0031-AC3 McAvatar', () {
    testWidgets('T-0031-AC3: an avatar is a circle of the given size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const McAvatar(image: _good, size: 48, semanticLabel: 'Wiimm'),
          bundle: McFixtureAssetBundle(),
        ),
      );
      expect(find.byType(ClipOval), findsOneWidget);
      expect(tester.getSize(find.byType(McAvatar)), const Size(48, 48));
    });
  });
}
