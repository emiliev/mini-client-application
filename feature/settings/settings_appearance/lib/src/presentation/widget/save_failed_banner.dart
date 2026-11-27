import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:settings_appearance/src/presentation/bloc/appearance_bloc.dart';
import 'package:settings_appearance/src/presentation/widget/settings_spacing.dart';

const saveFailedKey = ValueKey<String>('settings_appearance.save_failed');
const saveRetryKey = ValueKey<String>('settings_appearance.save_failed.retry');

/// The device could not keep the last choice: it applies now, but would not
/// survive a restart. Above the controls, which keep working; Retry saves
/// again.
class SaveFailedBanner extends StatelessWidget {
  const SaveFailedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    final p = context.mcPalette;
    final text = Theme.of(context).textTheme;
    return Semantics(
      key: saveFailedKey,
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: McRadius.mdAll,
          border: Border.all(color: p.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(McSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsAppearanceSaveFailedTitle,
                style: text.titleMedium!.copyWith(color: p.error),
              ),
              SizedBox(height: context.headerGap),
              Text(l10n.settingsAppearanceSaveFailed, style: text.bodyMedium),
              SizedBox(height: context.headerGap),
              McButton(
                key: saveRetryKey,
                label: McL10nCoreL10n.of(context).commonRetry,
                variant: McButtonVariant.secondary,
                onPressed: () => context.read<AppearanceBloc>().add(
                  const AppearanceEvent.retry(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
