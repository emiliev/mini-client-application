import 'package:mc_media/mc_media.dart';
import 'package:test/test.dart';

void main() {
  group('T-0030-AC6 ApiImage', () {
    test('T-0030-AC6: JSON round trip keeps path and variant', () {
      const sut = ApiImage(
        path: 'mock-asset://characters/017',
        variant: ImageVariant.landscape,
      );

      final restored = ApiImage.fromJson(sut.toJson());

      expect(restored, sut);
      expect(restored.hashCode, sut.hashCode);
      expect(sut.toJson(), {
        'path': 'mock-asset://characters/017',
        'variant': 'landscape',
      });
      expect(
        sut.toString(),
        'ApiImage(mock-asset://characters/017, landscape)',
      );
    });

    test('T-0030-AC6: images differing in variant or path are unequal', () {
      const sut = ApiImage(path: 'a');

      expect(sut == const ApiImage(path: 'a'), isTrue);
      expect(sut == const ApiImage(path: 'b'), isFalse);
      expect(
        sut == const ApiImage(path: 'a', variant: ImageVariant.standard),
        isFalse,
      );
    });

    test('T-0030-AC6: an unknown variant name is a FormatException', () {
      expect(
        () => ImageVariant.fromWire('huge'),
        throwsA(isA<FormatException>()),
      );
      expect(ImageVariant.fromWire('standard'), ImageVariant.standard);
    });
  });
}
