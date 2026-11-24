import 'package:mc_media/src/api_image.dart';

/// What an [McImageResolver] resolved an [ApiImage] to. Implementations add
/// what their loader needs (an asset key, a URL).
abstract interface class ResolvedImage {
  /// The size class it is drawn as.
  ImageVariant get variant;
}

/// Turns an [ApiImage] into something drawable. The app provides one through
/// `McMediaScope`: bundled placeholders in the mocked backend, a network
/// loader against a real one. Pure Dart, so fixtures and tests that never
/// draw can use it.
abstract interface class McImageResolver {
  /// Whether this resolver handles [image].
  bool canResolve(ApiImage image);

  /// Throws when [canResolve] is false or the image cannot be served.
  ResolvedImage resolve(ApiImage image);
}
