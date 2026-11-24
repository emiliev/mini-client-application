import 'package:mc_media/src/api_image.dart';

/// Where the bytes of a resolved image are, without saying how to load them.
/// Pure Dart: the UI package (`mc_ds_media`) maps each case to an
/// `ImageProvider` with an exhaustive `switch`.
sealed class ResolvedImage {
  const ResolvedImage(this.variant);

  /// An asset in the app bundle. [key] is the asset path; [package] is the
  /// package that declares it (`AssetImage(key, package: package)`).
  const factory ResolvedImage.asset(
    String key, {
    String? package,
    ImageVariant variant,
  }) = AssetResolvedImage;

  /// A picture to download.
  const factory ResolvedImage.network(Uri url, {ImageVariant variant}) =
      NetworkResolvedImage;

  /// The size class it is drawn as.
  final ImageVariant variant;
}

/// A bundled asset.
final class AssetResolvedImage extends ResolvedImage {
  const AssetResolvedImage(
    this.key, {
    this.package,
    ImageVariant variant = ImageVariant.portraitMedium,
  }) : super(variant);

  final String key;
  final String? package;

  @override
  bool operator ==(Object other) =>
      other is AssetResolvedImage &&
      other.key == key &&
      other.package == package &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(key, package, variant);

  @override
  String toString() => 'ResolvedImage.asset($key, package: $package)';
}

/// A picture behind a URL.
final class NetworkResolvedImage extends ResolvedImage {
  const NetworkResolvedImage(
    this.url, {
    ImageVariant variant = ImageVariant.portraitMedium,
  }) : super(variant);

  final Uri url;

  @override
  bool operator ==(Object other) =>
      other is NetworkResolvedImage &&
      other.url == url &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(url, variant);

  @override
  String toString() => 'ResolvedImage.network($url)';
}

/// Turns an [ApiImage] into a [ResolvedImage]. The app provides one through
/// `McMediaScope`: bundled placeholders in the mocked backend, a network
/// loader against a real one. Pure Dart, so fixtures and tests that never
/// draw can use it.
abstract interface class McImageResolver {
  /// Whether this resolver handles [image].
  bool canResolve(ApiImage image);

  /// Throws when [canResolve] is false or the image cannot be served.
  ResolvedImage resolve(ApiImage image);
}
