import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_ds_buttons/mc_ds_buttons.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:settings_home/src/domain/model/about_info.dart';
import 'package:settings_home/src/domain/model/account_view.dart';
import 'package:settings_home/src/l10n/settings_home_l10n.dart';
import 'package:settings_home/src/presentation/bloc/settings_home_bloc.dart';
import 'package:settings_home/src/presentation/widget/settings_spacing.dart';

/// Keys of the page's parts, for tests.
const settingsHomeBodyKey = ValueKey<String>('settings_home.body');
const settingsHomeAccountKey = ValueKey<String>('settings_home.account');
const settingsHomeSignInKey = ValueKey<String>('settings_home.sign_in');
const settingsHomeSignOutKey = ValueKey<String>('settings_home.sign_out');
const settingsHomeAppearanceKey = ValueKey<String>('settings_home.appearance');
const settingsHomeVersionKey = ValueKey<String>('settings_home.about.version');
const settingsHomeSeedKey = ValueKey<String>('settings_home.about.seed');

/// The settings index: provides the bloc and nothing else (Tide).
class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    // The only DI lookup in UI code (R17).
    create: (c) =>
        c.di<SettingsHomeBloc>()..add(const SettingsHomeEvent.load()),
    child: const _SettingsHomeContent(),
  );
}

class _SettingsHomeContent extends StatelessWidget {
  const _SettingsHomeContent();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: McAppBar(
      // The flow has its own navigator: this leaves the flow from its root
      // page.
      leading: const McFlowBackButton(),
      title: context.settingsL10n.settingsHomeTitle,
    ),
    body: BlocBuilder<SettingsHomeBloc, SettingsHomeState>(
      builder: (context, state) => state.when(
        loading: () => const McLoading(),
        ready: (account, themeMode, about, busy) => _Settings(
          account: account,
          themeMode: themeMode,
          about: about,
          busy: busy,
        ),
      ),
    ),
  );
}

class _Settings extends StatelessWidget {
  const _Settings({
    required this.account,
    required this.themeMode,
    required this.about,
    required this.busy,
  });

  final AccountView account;
  final AppearanceThemeMode themeMode;
  final AboutInfo about;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    return ListView(
      key: settingsHomeBodyKey,
      padding: EdgeInsets.symmetric(
        horizontal: McSpacing.lg,
        vertical: context.sectionGap,
      ),
      children: [
        _Header(l10n.settingsHomeAccountHeader),
        _AccountRow(account: account, busy: busy),
        SizedBox(height: context.sectionGap),
        ListTile(
          key: settingsHomeAppearanceKey,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsHomeAppearance),
          subtitle: Text(_themeLabel(l10n, themeMode)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.read<SettingsHomeBloc>().add(
            const SettingsHomeEvent.openAppearance(),
          ),
        ),
        SizedBox(height: context.sectionGap),
        _Header(l10n.settingsHomeAboutHeader),
        ListTile(
          key: settingsHomeVersionKey,
          contentPadding: EdgeInsets.zero,
          title: Text(
            about.version == null
                ? l10n.settingsHomeAboutBuild
                : l10n.settingsHomeAboutVersion,
          ),
          subtitle: Text(
            about.version == null
                ? about.build
                : l10n.settingsHomeAboutVersionValue(
                    about.version!,
                    about.build,
                  ),
          ),
        ),
        ListTile(
          key: settingsHomeSeedKey,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsHomeAboutSeed),
          subtitle: Text('${about.seed}'),
        ),
      ],
    );
  }
}

/// The label of a theme mode: every value has one (the switch is
/// exhaustive, so a new mode in `mc_appearance` fails to compile here).
String _themeLabel(SettingsHomeL10n l10n, AppearanceThemeMode mode) =>
    switch (mode) {
      AppearanceThemeMode.system => l10n.settingsHomeThemeSystem,
      AppearanceThemeMode.light => l10n.settingsHomeThemeLight,
      AppearanceThemeMode.dark => l10n.settingsHomeThemeDark,
    };

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.headerGap),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall!.copyWith(
          color: context.mcPalette.onSurfaceMuted,
        ),
      ),
    ),
  );
}

/// Who is signed in, with Sign in or Sign out. A static wait while the app
/// signs someone in or out, no spinner: it may wait for the user
/// indefinitely (F-0048 §5.10).
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.busy});

  final AccountView account;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.settingsL10n;
    final bloc = context.read<SettingsHomeBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (account) {
          SignedOutAccount() => ListTile(
            key: settingsHomeAccountKey,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsHomeNotSignedIn),
          ),
          final SignedInAccount signedIn => ListTile(
            key: settingsHomeAccountKey,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsHomeSignedInAs(signedIn.name)),
            subtitle: signedIn.profile == null
                ? null
                : Text(signedIn.profile!.email),
          ),
        },
        SizedBox(height: context.headerGap),
        switch (account) {
          SignedOutAccount() => McButton(
            key: settingsHomeSignInKey,
            label: l10n.settingsHomeSignIn,
            variant: McButtonVariant.secondary,
            expand: true,
            onPressed: busy
                ? null
                : () => bloc.add(const SettingsHomeEvent.signIn()),
          ),
          SignedInAccount() => McButton(
            key: settingsHomeSignOutKey,
            label: l10n.settingsHomeSignOut,
            variant: McButtonVariant.secondary,
            expand: true,
            onPressed: busy
                ? null
                : () => bloc.add(const SettingsHomeEvent.signOut()),
          ),
        },
      ],
    );
  }
}
