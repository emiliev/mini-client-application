import 'package:flutter/widgets.dart';
import 'package:mc_media/mc_media.dart';

/// The [ImageProvider] for [resolved]: an exhaustive mapping of where the
/// bytes are to how Flutter loads them.
ImageProvider mcImageProviderFor(ResolvedImage resolved) {
  return switch (resolved) {
    AssetResolvedImage(:final key, :final package) => AssetImage(
      key,
      package: package,
    ),
    NetworkResolvedImage(:final url) => NetworkImage(url.toString()),
  };
}
