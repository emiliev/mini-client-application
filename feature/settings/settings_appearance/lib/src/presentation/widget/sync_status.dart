import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:settings_appearance/src/presentation/bloc/appearance_bloc.dart';
import 'package:settings_appearance/src/presentation/widget/settings_spacing.dart';

const syncStatusKey = ValueKey<String>('settings_appearance.sync');
const syncRetryKey = ValueKey<String>('settings_appearance.sync.retry');
const syncAcrossDevicesKey = ValueKey<String>('settings_appearance.sync_cta');

/// Where the choice stands: a status line, with Retry after a failed sync,
/// and "Sync across devices" while signed out.
class SyncStatus extends StatelessWidget {
  const SyncStatus({required this.sync, required this.signingIn, super.key});

  final AppearanceSyncStatus sync;
  final bool signingIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    final bloc = context.read<AppearanceBloc>();
    final text = switch (sync) {
      _ when signingIn => l10n.settingsAppearanceSigningIn,
      AppearanceSyncStatus.local => l10n.settingsAppearanceSyncLocal,
      AppearanceSyncStatus.pending => l10n.settingsAppearanceSyncPending,
      AppearanceSyncStatus.synced => l10n.settingsAppearanceSyncSynced,
      AppearanceSyncStatus.offline => l10n.settingsAppearanceSyncOffline,
      AppearanceSyncStatus.conflictResolved =>
        l10n.settingsAppearanceSyncConflictResolved,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Announced when it changes: a sync ends while the user looks away.
        Semantics(
          liveRegion: true,
          child: Text(
            text,
            key: syncStatusKey,
            style:
                Theme.of(
                      context,
                    ).textTheme.bodyMedium!
                    .copyWith(color: context.mcPalette.onSurfaceMuted),
          ),
        ),
        if (sync == AppearanceSyncStatus.offline) ...[
          SizedBox(height: context.headerGap),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: McButton(
              key: syncRetryKey,
              label: McL10nCoreL10n.of(context).commonRetry,
              variant: McButtonVariant.secondary,
              onPressed: () => bloc.add(const AppearanceEvent.retry()),
            ),
          ),
        ],
        if (sync == AppearanceSyncStatus.local) ...[
          SizedBox(height: context.headerGap),
          McButton(
            key: syncAcrossDevicesKey,
            label: l10n.settingsAppearanceSyncAcrossDevices,
            variant: McButtonVariant.secondary,
            expand: true,
            // A static wait, no spinner: it may wait for the user
            // indefinitely (F-0048 §5.10).
            onPressed: signingIn
                ? null
                : () => bloc.add(const AppearanceEvent.syncAcrossDevices()),
          ),
        ],
        const SizedBox(height: McSpacing.xs),
      ],
    );
  }
}
