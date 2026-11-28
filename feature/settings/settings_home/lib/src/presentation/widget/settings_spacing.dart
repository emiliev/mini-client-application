import 'package:flutter/material.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:settings_home/src/l10n/settings_home_l10n.dart';

/// The screen's spacing under the app's density (ADR-0013): `Compact` sets
/// `ThemeData.visualDensity` to `VisualDensity.compact`, and every gap of
/// this screen tightens with it.
extension SettingsHomeSpacing on BuildContext {
  /// Whether the app runs at a compact density.
  bool get isCompact => Theme.of(this).visualDensity == VisualDensity.compact;

  /// The gap between two sections of the screen.
  double get sectionGap => isCompact ? McSpacing.md : McSpacing.xl;

  /// The gap between a section's header and its rows.
  double get headerGap => isCompact ? McSpacing.xs : McSpacing.sm;

  /// The feature's strings.
  SettingsHomeL10n get settingsL10n => SettingsHomeL10n.of(this);
}
