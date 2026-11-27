import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:settings_appearance/src/presentation/bloc/appearance_bloc.dart';
import 'package:settings_appearance/src/presentation/widget/appearance_controls.dart';
import 'package:settings_appearance/src/presentation/widget/settings_spacing.dart';
import 'package:settings_appearance/src/presentation/widget/sync_status.dart';

/// Key of the screen's scrolling body, for tests.
const appearanceBodyKey = ValueKey<String>('settings_appearance.body');
const aboutThemesKey = ValueKey<String>('settings_appearance.about');
const resetKey = ValueKey<String>('settings_appearance.reset');

/// The appearance settings: provides the bloc and nothing else (Tide).
class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (c) => c.di<AppearanceBloc>()..add(const AppearanceEvent.load()),
    child: const _AppearanceContent(),
  );
}

class _AppearanceContent extends StatelessWidget {
  const _AppearanceContent();

  /// "Reset to defaults" asks first (the DS confirm, F-0058); only a confirm
  /// reaches the bloc, so Cancel changes nothing.
  Future<void> _confirmReset(BuildContext context) async {
    final l10n = context.settingsL10n;
    final bloc = context.read<AppearanceBloc>();
    final confirmed = await showMcConfirm(
      context,
      title: l10n.settingsAppearanceResetTitle,
      message: l10n.settingsAppearanceResetMessage,
      confirmLabel: l10n.settingsAppearanceResetConfirm,
      cancelLabel: McL10nCoreL10n.of(context).commonCancel,
      destructive: true,
    );
    if (confirmed && !bloc.isClosed) {
      bloc.add(const AppearanceEvent.reset());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    return Scaffold(
      appBar: McAppBar(
        // The flow has its own navigator: this leaves the flow from its
        // root page.
        leading: const McFlowBackButton(),
        title: l10n.settingsAppearanceTitle,
      ),
      body: BlocBuilder<AppearanceBloc, AppearanceState>(
        builder: (context, state) => state.when(
          loading: () => const McLoading(),
          failure: (preferences, error, stackTrace) => McErrorView(
            title: l10n.settingsAppearanceSaveFailedTitle,
            message: l10n.settingsAppearanceSaveFailed,
            retryLabel: McL10nCoreL10n.of(context).commonRetry,
            onRetry: () => context.read<AppearanceBloc>().add(
              const AppearanceEvent.retry(),
            ),
          ),
          ready: (preferences, sync, signingIn) => ListView(
            key: appearanceBodyKey,
            padding: EdgeInsets.symmetric(
              horizontal: McSpacing.lg,
              vertical: context.groupGap,
            ),
            children: [
              AppearanceControls(preferences: preferences),
              SizedBox(height: context.groupGap),
              SyncStatus(sync: sync, signingIn: signingIn),
              SizedBox(height: context.groupGap),
              McButton(
                key: aboutThemesKey,
                label: l10n.settingsAppearanceAbout,
                variant: McButtonVariant.tertiary,
                onPressed: () => context.read<AppearanceBloc>().add(
                  const AppearanceEvent.openAbout(),
                ),
              ),
              SizedBox(height: context.headerGap),
              McButton(
                key: resetKey,
                label: l10n.settingsAppearanceReset,
                variant: McButtonVariant.tertiary,
                onPressed: () => _confirmReset(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
