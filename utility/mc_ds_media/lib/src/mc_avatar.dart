import 'package:flutter/material.dart';
import 'package:mc_ds_media/src/mc_image.dart';
import 'package:mc_media/mc_media.dart';

/// A circular [McImage].
class McAvatar extends StatelessWidget {
  const McAvatar({
    required this.image,
    this.size = 40,
    this.semanticLabel,
    super.key,
  });

  final ApiImage image;

  /// Diameter in logical pixels.
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: McImage(
        image: image,
        variant: ImageVariant.standard,
        width: size,
        height: size,
        semanticLabel: semanticLabel,
      ),
    );
  }
}
