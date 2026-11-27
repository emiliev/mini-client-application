import 'package:flutter/material.dart';
import 'package:settings_appearance/src/l10n/settings_appearance_l10n.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';

/// The screen's spacing under the app's density (ADR-0013): `Compact` sets
/// `ThemeData.visualDensity` to `VisualDensity.compact`, and every gap and
/// row of this screen tightens with it.
extension SettingsSpacing on BuildContext {
  /// Whether the app runs at a compact density.
  bool get isCompact => Theme.of(this).visualDensity == VisualDensity.compact;

  /// The gap between two groups of the screen.
  double get groupGap => isCompact ? McSpacing.md : McSpacing.xl;

  /// The gap between a group's header and its control.
  double get headerGap => isCompact ? McSpacing.xs : McSpacing.sm;

  /// The feature's strings.
  SettingsAppearanceL10n get settingsL10n => SettingsAppearanceL10n.of(this);
}
