import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:settings_appearance/src/presentation/bloc/appearance_bloc.dart';
import 'package:settings_appearance/src/presentation/widget/settings_spacing.dart';

/// Keys of the controls, for tests (plan 05 §3.5: steps find by key).
ValueKey<String> themeModeKey(AppearanceThemeMode mode) =>
    ValueKey('settings_appearance.theme.${mode.wire}');
ValueKey<String> densityKey(AppearanceDensity density) =>
    ValueKey('settings_appearance.density.${density.wire}');
const reduceMotionKey = ValueKey<String>('settings_appearance.reduce_motion');

/// The three choices: theme mode, density and reduce motion. Each control
/// shows [preferences] and dispatches the user's choice; the bloc decides.
class AppearanceControls extends StatelessWidget {
  const AppearanceControls({required this.preferences, super.key});

  final AppearancePreferences preferences;

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    final bloc = context.read<AppearanceBloc>();
    String themeLabel(AppearanceThemeMode mode) => switch (mode) {
      AppearanceThemeMode.system => l10n.settingsAppearanceThemeSystem,
      AppearanceThemeMode.light => l10n.settingsAppearanceThemeLight,
      AppearanceThemeMode.dark => l10n.settingsAppearanceThemeDark,
    };
    String densityLabel(AppearanceDensity density) => switch (density) {
      AppearanceDensity.comfortable =>
        l10n.settingsAppearanceDensityComfortable,
      AppearanceDensity.compact => l10n.settingsAppearanceDensityCompact,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        McSectionHeader(title: l10n.settingsAppearanceThemeHeader),
        SizedBox(height: context.headerGap),
        McSegmented(
          segments: [
            for (final mode in AppearanceThemeMode.values)
              McSegment(label: themeLabel(mode), key: themeModeKey(mode)),
          ],
          selectedIndex: preferences.themeMode.index,
          onChanged: (i) => bloc.add(
            AppearanceEvent.setThemeMode(AppearanceThemeMode.values[i]),
          ),
        ),
        SizedBox(height: context.groupGap),
        McSectionHeader(title: l10n.settingsAppearanceDensityHeader),
        SizedBox(height: context.headerGap),
        McSegmented(
          segments: [
            for (final density in AppearanceDensity.values)
              McSegment(label: densityLabel(density), key: densityKey(density)),
          ],
          selectedIndex: preferences.density.index,
          onChanged: (i) => bloc.add(
            AppearanceEvent.setDensity(AppearanceDensity.values[i]),
          ),
        ),
        SizedBox(height: context.groupGap),
        // A Material switch row: it sizes itself by the theme's density too.
        SwitchListTile.adaptive(
          key: reduceMotionKey,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsAppearanceReduceMotion),
          subtitle: Text(l10n.settingsAppearanceReduceMotionHint),
          value: preferences.reduceMotion,
          onChanged: (on) => bloc.add(AppearanceEvent.setReduceMotion(on: on)),
        ),
      ],
    );
  }
}
