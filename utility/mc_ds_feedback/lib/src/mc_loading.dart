import 'package:flutter/material.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';

/// A centred progress indicator. Announces [semanticLabel] to screen readers.
class McLoading extends StatelessWidget {
  const McLoading({this.semanticLabel = 'Loading', super.key});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: semanticLabel,
        liveRegion: true,
        child: CircularProgressIndicator(
          color: context.mcPalette.primary,
          // Excluded: the wrapping Semantics already carries the label.
          semanticsLabel: null,
        ),
      ),
    );
  }
}
