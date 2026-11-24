import 'package:flutter/material.dart';
import 'package:mc_ds_layout/mc_ds_layout.dart';
import 'package:mc_ds_media/src/image_provider_for.dart';
import 'package:mc_ds_media/src/mc_media_scope.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_media/mc_media.dart';

/// An [ApiImage] resolved through the nearest [McMediaScope].
///
/// Shows a placeholder until the picture has loaded, cross-fades to it (no
/// fade under reduced motion) and shows a fallback when the image cannot be
/// resolved or loaded. Failures never throw. Without a [McMediaScope] it
/// throws a [FlutterError] naming the scope: that is a wiring bug.
///
/// The image is excluded from semantics unless [semanticLabel] is given.
class McImage extends StatelessWidget {
  const McImage({
    required this.image,
    this.variant,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.semanticLabel,
    super.key,
  });

  /// Keys of the three states, for tests.
  static const placeholderKey = Key('mc_image_placeholder');
  static const fallbackKey = Key('mc_image_fallback');
  static const loadedKey = Key('mc_image_loaded');

  final ApiImage image;

  /// Overrides `image.variant`.
  final ImageVariant? variant;
  final BoxFit fit;

  /// Without [width] and [height] the widget takes the aspect ratio of the
  /// variant and fills the width it is given.
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Throws a FlutterError naming McMediaScope when there is none.
    final resolver = McMediaScope.of(context);
    final effective = variant == null
        ? image
        : ApiImage(path: image.path, variant: variant!);
    final provider = _providerFor(resolver, effective);
    final palette = context.mcPalette;
    final Widget content = provider == null
        ? _Fallback(key: fallbackKey, palette: palette)
        : _Loaded(
            provider: provider,
            fit: fit,
            fade: McA11y.duration(context, McMotion.normal),
            palette: palette,
          );
    final Widget sized = (width != null || height != null)
        ? SizedBox(width: width, height: height, child: content)
        : AspectRatio(
            aspectRatio: effective.variant.width / effective.variant.height,
            child: content,
          );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: sized)
        : Semantics(
            image: true,
            label: label,
            child: ExcludeSemantics(child: sized),
          );
  }

  /// Null when the image cannot be resolved: an expected state, drawn as the
  /// fallback.
  static ImageProvider? _providerFor(McImageResolver resolver, ApiImage image) {
    try {
      if (!resolver.canResolve(image)) {
        return null;
      }
      return mcImageProviderFor(resolver.resolve(image));
    } on Object catch (_) {
      return null;
    }
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.provider,
    required this.fit,
    required this.fade,
    required this.palette,
  });

  final ImageProvider provider;
  final BoxFit fit;
  final Duration fade;
  final McPalette palette;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: provider,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final ready = wasSynchronouslyLoaded || frame != null;
        return AnimatedSwitcher(
          duration: wasSynchronouslyLoaded ? Duration.zero : fade,
          child: ready
              ? KeyedSubtree(key: McImage.loadedKey, child: child)
              : _Placeholder(key: McImage.placeholderKey, palette: palette),
        );
      },
      errorBuilder: (context, error, stack) =>
          _Fallback(key: McImage.fallbackKey, palette: palette),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.palette, super.key});

  final McPalette palette;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: palette.surfaceVariant, child: const SizedBox.expand());
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.palette, super.key});

  final McPalette palette;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: palette.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: palette.onSurfaceMuted,
        ),
      ),
    );
  }
}
