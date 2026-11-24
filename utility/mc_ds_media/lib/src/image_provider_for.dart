import 'package:flutter/widgets.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';

/// The [ImageProvider] for [resolved], or null when this package does not know
/// how to draw that kind of image. Bundled placeholder art becomes an
/// [AssetImage]; a network resolver will add its own case.
ImageProvider? mcImageProviderFor(ResolvedImage resolved) {
  return switch (resolved) {
    final BundledImage bundled => AssetImage(bundled.assetKey),
    _ => null,
  };
}
