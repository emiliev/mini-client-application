import 'package:flutter/painting.dart';
import 'package:mc_media/mc_media.dart';

/// How many placeholder images each set bundles. Image ids run `000` to
/// `count - 1`. Keep in step with `tool/generate_placeholders.dart`.
const Map<String, int> placeholderSets = {'characters': 24};

final RegExp _digits = RegExp(r'^\d+$');

const String mockAssetScheme = 'mock-asset';

/// A bundled asset an [ApiImage] resolved to.
final class BundledImage implements ResolvedImage {
  const BundledImage({
    required this.set,
    required this.id,
    required this.variant,
  });

  final String set;

  /// Zero-padded to three digits, e.g. `017`.
  final String id;
  @override
  final ImageVariant variant;

  @override
  ImageProvider get provider => AssetImage(assetKey);

  /// The 1x file inside this package, e.g. `assets/characters/017.png`.
  /// Flutter finds the `2.0x/` and `3.0x/` siblings by itself.
  String get packageRelativePath => 'assets/$set/$id.png';

  /// What `AssetImage` takes with no `package:` argument.
  String get assetKey => 'packages/mc_fixtures_media/$packageRelativePath';

  /// Every density variant, 1x first.
  List<String> get allDensityPaths => [
    packageRelativePath,
    'assets/$set/2.0x/$id.png',
    'assets/$set/3.0x/$id.png',
  ];
}

/// Thrown for a path the bundle cannot serve.
final class UnresolvedImageException implements Exception {
  const UnresolvedImageException(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => 'UnresolvedImageException: $path ($reason)';
}

/// Turns `mock-asset://<set>/<id>` into a bundled asset.
final class BundledImageResolver implements McImageResolver {
  const BundledImageResolver();

  /// Whether this resolver handles [image]. Anything else goes to the
  /// network loader.
  @override
  bool canResolve(ApiImage image) =>
      Uri.tryParse(image.path)?.scheme == mockAssetScheme;

  @override
  BundledImage resolve(ApiImage image) {
    final uri = Uri.tryParse(image.path);
    if (uri == null || uri.scheme != mockAssetScheme) {
      throw UnresolvedImageException(
        image.path,
        'not a $mockAssetScheme:// path',
      );
    }
    final set = uri.host;
    final count = placeholderSets[set];
    if (count == null) {
      throw UnresolvedImageException(image.path, 'unknown set "$set"');
    }
    final segments = uri.pathSegments;
    final index = segments.length == 1 && _digits.hasMatch(segments.single)
        ? int.tryParse(segments.single)
        : null;
    if (index == null || index < 0 || index >= count) {
      throw UnresolvedImageException(
        image.path,
        'id must be a number from 0 to ${count - 1}',
      );
    }
    return BundledImage(
      set: set,
      id: index.toString().padLeft(3, '0'),
      variant: image.variant,
    );
  }
}
