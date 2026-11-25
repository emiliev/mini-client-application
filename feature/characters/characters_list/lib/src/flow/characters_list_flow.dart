import 'package:characters_list/src/di/di_initializer.dart';
import 'package:characters_list/src/di/flow_scope.dart';
import 'package:characters_list/src/flow/characters_list_flow_state.dart';
import 'package:characters_list/src/l10n/characters_list_l10n.dart';
import 'package:characters_list/src/navigator/characters_list_navigator.dart';
import 'package:characters_list/src/presentation/page/character_preview_page.dart';
import 'package:characters_list/src/presentation/page/characters_list_page.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// The feature's only entry point (R4): a paged grid of characters whose
/// preview opens inside the flow, and whose "See full profile" leaves the
/// feature through [navigator].
///
/// The app builds it from a route (`RouteTargets`, T-0033) with the
/// navigator implementation from its wiring; tests pass a mock.
///
/// Immutable after creation: the flow reads [navigator] and [initialTeamId]
/// once, when its scope opens (`provide:` runs once per flow instance). A
/// rebuild with a different navigator keeps the first one; a different
/// [initialTeamId] builds a new flow (its
/// `FeatureFlow` is keyed by it), with a fresh scope, state and first page.
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
  Widget build(BuildContext context) => FeatureFlow<CharactersListFlowState>(
    key: ValueKey(initialTeamId),
    flowInitializer: const CharactersListDIInitializer(),
    rootImports: charactersListRootImports,
    provide: (scope) =>
        scope.registerSingleton<CharactersListNavigator>(navigator),
    localizationsDelegates: const [CharactersListL10n.delegate],
    state: CharactersListFlowState(teamId: initialTeamId),
    onGeneratePages: (state) => [
      const McFlowPage(name: 'list', child: CharactersListPage()),
      if (state.preview case final character?)
        McFlowPage(
          name: 'preview',
          arguments: character.id,
          child: CharacterPreviewPage(
            key: ValueKey(character.id),
            character: character,
          ),
        ),
    ],
  );
}
