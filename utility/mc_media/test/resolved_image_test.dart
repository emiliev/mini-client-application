import 'package:mc_media/mc_media.dart';
import 'package:test/test.dart';

void main() {
  group('T-0031-AC6 ResolvedImage', () {
    test('T-0031-AC6: asset keeps key, package and variant, with equality', () {
      const sut = ResolvedImage.asset(
        'assets/a.png',
        package: 'p',
        variant: ImageVariant.landscape,
      );

      expect(sut, isA<AssetResolvedImage>());
      expect((sut as AssetResolvedImage).key, 'assets/a.png');
      expect(sut.package, 'p');
      expect(sut.variant, ImageVariant.landscape);
      expect(
        sut,
        const ResolvedImage.asset(
          'assets/a.png',
          package: 'p',
          variant: ImageVariant.landscape,
        ),
      );
      expect(sut.hashCode, sut.hashCode);
      expect(sut == const ResolvedImage.asset('assets/a.png'), isFalse);
      expect(sut.toString(), 'ResolvedImage.asset(assets/a.png, package: p)');
      expect(
        const ResolvedImage.asset('x').variant,
        ImageVariant.portraitMedium,
      );
    });

    test('T-0031-AC6: network keeps url and variant, with equality', () {
      final url = Uri.parse('https://x.test/a.png');
      final sut = ResolvedImage.network(url, variant: ImageVariant.standard);

      expect(sut, isA<NetworkResolvedImage>());
      expect((sut as NetworkResolvedImage).url, url);
      expect(sut.variant, ImageVariant.standard);
      expect(sut, ResolvedImage.network(url, variant: ImageVariant.standard));
      expect(
        sut.hashCode,
        ResolvedImage.network(url, variant: ImageVariant.standard).hashCode,
      );
      expect(sut == ResolvedImage.network(url), isFalse);
      expect(sut.toString(), 'ResolvedImage.network(https://x.test/a.png)');
    });

    test('T-0031-AC6: a switch over ResolvedImage is exhaustive', () {
      String where(ResolvedImage r) => switch (r) {
        AssetResolvedImage(:final key) => 'asset $key',
        NetworkResolvedImage(:final url) => 'net $url',
      };

      expect(where(const ResolvedImage.asset('k')), 'asset k');
      expect(where(ResolvedImage.network(Uri.parse('u:x'))), 'net u:x');
    });
  });
}
