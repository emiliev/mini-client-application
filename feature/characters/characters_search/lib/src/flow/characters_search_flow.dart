import 'package:characters_search/src/di/di_initializer.dart';
import 'package:characters_search/src/di/flow_scope.dart';
import 'package:characters_search/src/domain/model/character_analytics.dart';
import 'package:characters_search/src/flow/characters_search_flow_state.dart';
import 'package:characters_search/src/l10n/characters_search_l10n.dart';
import 'package:characters_search/src/navigator/characters_search_navigator.dart';
import 'package:characters_search/src/presentation/page/characters_search_page.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

/// The feature's only entry point (R4): search the characters by the start of
/// their name, sorted and narrowed by facets, whose results leave the feature
/// through [navigator].
///
/// The app builds it from a route (`/characters/search?q=`, universe_wiring)
/// with the navigator implementation from its wiring; tests pass a mock. It
/// can start from a query alone (plan 01 §4.4).
///
/// Its one page is the screen `characters_search`, tracked from inside the
/// flow by `AnalyticsFlowObserver` (ADR-0012).
///
/// Immutable after creation: the flow reads [navigator] and [initialQuery]
/// once, when its scope opens (`provide:` runs once per flow instance). A
/// rebuild with a different navigator keeps the first one; a different
/// [initialQuery] builds a new flow (its `FeatureFlow` is keyed by it), with
/// a fresh scope, state and page.
class CharactersSearchFlow extends StatelessWidget {
  const CharactersSearchFlow({
    required this.navigator,
    this.initialQuery,
    super.key,
  });

  final CharactersSearchNavigator navigator;

  /// Starts the search with this text in the field, searched at once. Null
  /// or blank opens on the recent searches, with the keyboard up.
  final String? initialQuery;

  /// [initialQuery], with a blank one as none (`/characters/search?q=`).
  String? get _query {
    final query = initialQuery;
    return query == null || query.trim().isEmpty ? null : query;
  }

  @override
  Widget build(BuildContext context) => FeatureFlow<CharactersSearchFlowState>(
    key: ValueKey(_query),
    flowInitializer: const CharactersSearchDIInitializer(),
    rootImports: charactersSearchRootImports,
    provide: (scope) =>
        scope.registerSingleton<CharactersSearchNavigator>(navigator),
    localizationsDelegates: const [CharactersSearchL10n.delegate],
    // The flow's pages are screens: resolved inside the flow, without a
    // dependency on the host route (F-0056 section 4).
    observers: [
      AnalyticsFlowObserver(
        (context) => context.di<AnalyticsTracker>(),
        host: (context) => FlowScope.read(context).outerRoute,
      ),
    ],
    state: CharactersSearchFlowState(initialQuery: _query),
    onGeneratePages: (state) => [
      McFlowPage(
        name: charactersSearchScreen,
        arguments: state.initialQuery,
        child: CharactersSearchPage(initialQuery: state.initialQuery),
      ),
    ],
  );
}
