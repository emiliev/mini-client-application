import 'package:flutter/material.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// Carries the [McPalette] on `ThemeData.extensions`, so widgets read tokens
/// from the theme instead of hard-coding colours.
@immutable
class McThemeExtension extends ThemeExtension<McThemeExtension> {
  const McThemeExtension({required this.variant, required this.palette});

  final McThemeVariant variant;
  final McPalette palette;

  @override
  McThemeExtension copyWith({McThemeVariant? variant, McPalette? palette}) =>
      McThemeExtension(
        variant: variant ?? this.variant,
        palette: palette ?? this.palette,
      );

  @override
  McThemeExtension lerp(McThemeExtension? other, double t) {
    if (other == null) return this;
    return McThemeExtension(
      variant: t < 0.5 ? variant : other.variant,
      palette: McPalette.lerp(palette, other.palette, t),
    );
  }
}

extension McThemeContext on BuildContext {
  McThemeExtension get mcTheme {
    final extension = Theme.of(this).extension<McThemeExtension>();
    assert(
      extension != null,
      'No McThemeExtension: build the theme with McTheme.of().',
    );
    return extension!;
  }

  McPalette get mcPalette => mcTheme.palette;
}
