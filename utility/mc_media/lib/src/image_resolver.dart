import 'package:flutter/painting.dart';
import 'package:mc_media/src/api_image.dart';

/// What an [McImageResolver] resolved an [ApiImage] to: the variant it is
/// drawn as and a provider that loads the pixels.
abstract interface class ResolvedImage {
  ImageVariant get variant;

  ImageProvider get provider;
}

/// Turns an [ApiImage] into something drawable. The app provides one through
/// `McMediaScope`: bundled placeholders in the mocked backend, a network
/// loader against a real one.
abstract interface class McImageResolver {
  /// Whether this resolver handles [image].
  bool canResolve(ApiImage image);

  /// Throws when [canResolve] is false or the image cannot be served.
  ResolvedImage resolve(ApiImage image);
}
