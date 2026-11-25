import 'package:characters_list/src/di/di_initializer.dart';
import 'package:characters_list/src/di/flow_scope.dart';
import 'package:characters_list/src/flow/characters_list_flow_state.dart';
import 'package:characters_list/src/l10n/characters_list_l10n.dart';
import 'package:characters_list/src/navigator/characters_list_navigator.dart';
import 'package:characters_list/src/presentation/page/character_preview_page.dart';
import 'package:characters_list/src/presentation/page/characters_list_page.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// The feature's only entry point (R4): a paged grid of characters whose
/// preview opens inside the flow, and whose "See full profile" leaves the
/// feature through [navigator].
///
/// The app builds it from a route (`RouteTargets`, T-0033) with the
/// navigator implementation from its wiring; tests pass a mock.
class CharactersListFlow extends StatelessWidget {
  const CharactersListFlow({
    required this.navigator,
    this.initialTeamId,
    super.key,
  });

  final CharactersListNavigator navigator;

  /// Starts the list filtered to one team.
  final String? initialTeamId;

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    // The feature's strings, then the core strings (Retry, error copy) and
    // Flutter's own, whatever the host app installed (plan 01 §3.3 passes
    // these to the flow; mc_feature_flow has no `localizationsDelegates` yet).
    delegates: const [
      CharactersListL10n.delegate,
      ...mcLocalizationsDelegates,
    ],
    child: FeatureFlow<CharactersListFlowState>(
      state: CharactersListFlowState(teamId: initialTeamId),
      rootImports: charactersListRootImports,
      flowInitializer: McDIInitializer(_initializeWith(navigator)),
      onGeneratePages: (state) => [
        const McFlowPage(name: 'list', child: CharactersListPage()),
        if (state.previewId case final id?)
          McFlowPage(
            name: 'preview',
            arguments: id,
            child: CharacterPreviewPage(characterId: id),
          ),
      ],
    ),
  );
}

/// The flow's container: the navigator the app passed (plan 01's `provide:`,
/// which `FeatureFlow` does not have yet), then the package's injectable
/// registrations.
GetItInitializer _initializeWith(CharactersListNavigator navigator) =>
    (GetIt getIt, String? environment) async {
      getIt.registerSingleton<CharactersListNavigator>(navigator);
      await const CharactersListDIInitializer().init(getIt);
    };
