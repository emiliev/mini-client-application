import 'package:characters_details/src/di/di_initializer.dart';
import 'package:characters_details/src/di/flow_scope.dart';
import 'package:characters_details/src/domain/model/character_analytics.dart';
import 'package:characters_details/src/domain/model/character_id.dart';
import 'package:characters_details/src/flow/characters_details_flow_state.dart';
import 'package:characters_details/src/l10n/characters_details_l10n.dart';
import 'package:characters_details/src/navigator/characters_details_navigator.dart';
import 'package:characters_details/src/presentation/page/character_details_page.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The feature's only entry point (R4): one character's profile in sections
/// (header, bio, stats, comics, favourite). Its comics and its favourite
/// leave the feature through [navigator].
///
/// The app builds it from a route (`/characters/:id`, universe_wiring) with
/// the navigator implementation from its wiring; tests pass a mock. It starts
/// from the id alone (plan 01 §4.4).
///
/// Its one page is the screen `character_details`, tracked from inside the
/// flow by `AnalyticsFlowObserver` (ADR-0012).
///
/// Immutable after creation: the flow reads [navigator] and [characterId]
/// once, when its scope opens (`provide:` runs once per flow instance). A
/// rebuild with a different navigator keeps the first one; a different
/// [characterId] builds a new flow (its `FeatureFlow` is keyed by it), with a
/// fresh scope, state and first page.
class CharacterDetailsFlow extends StatelessWidget {
  const CharacterDetailsFlow({
    required this.navigator,
    required this.characterId,
    super.key,
  });

  final CharacterDetailsNavigator navigator;

  /// The character to show.
  final CharacterId characterId;

  @override
  Widget build(BuildContext context) => FeatureFlow<CharacterDetailsFlowState>(
    key: ValueKey(characterId),
    flowInitializer: const CharacterDetailsDIInitializer(),
    rootImports: characterDetailsRootImports,
    provide: (scope) =>
        scope.registerSingleton<CharacterDetailsNavigator>(navigator),
    localizationsDelegates: const [CharacterDetailsL10n.delegate],
    // The flow's pages are screens: resolved inside the flow, without a
    // dependency on the host route (F-0056 section 4).
    observers: [
      AnalyticsFlowObserver(
        (context) => context.di<AnalyticsTracker>(),
        host: (context) => FlowScope.read(context).outerRoute,
      ),
    ],
    state: CharacterDetailsFlowState(characterId: characterId),
    onGeneratePages: (state) => [
      McFlowPage(
        name: characterDetailsScreen,
        arguments: state.characterId,
        child: const CharacterDetailsPage(),
      ),
    ],
  );
}
