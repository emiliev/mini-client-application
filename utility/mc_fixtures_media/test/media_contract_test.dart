import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';

void main() {
  test('T-0030-AC6: BundledImageResolver is an McImageResolver', () {
    const McImageResolver sut = BundledImageResolver();

    expect(sut, isA<McImageResolver>());
    expect(
      sut.canResolve(const ApiImage(path: 'mock-asset://characters/3')),
      isTrue,
    );
    expect(
      sut.canResolve(const ApiImage(path: 'https://x.test/a.png')),
      isFalse,
    );
  });

  test('T-0030-AC6: a resolved bundled image is a ResolvedImage', () {
    const McImageResolver sut = BundledImageResolver();

    final ResolvedImage resolved = sut.resolve(
      const ApiImage(
        path: 'mock-asset://characters/3',
        variant: ImageVariant.standard,
      ),
    );

    expect(resolved.variant, ImageVariant.standard);
    expect(
      (resolved as BundledImage).assetKey,
      'packages/mc_fixtures_media/assets/characters/003.png',
    );
  });
}
