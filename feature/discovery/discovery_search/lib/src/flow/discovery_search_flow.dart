import 'package:discovery_search/src/di/di_initializer.dart';
import 'package:discovery_search/src/di/flow_scope.dart';
import 'package:discovery_search/src/flow/discovery_search_flow_state.dart';
import 'package:discovery_search/src/l10n/discovery_search_l10n.dart';
import 'package:discovery_search/src/navigator/discovery_search_navigator.dart';
import 'package:discovery_search/src/presentation/page/discovery_search_page.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// The feature's only entry point (R4): search across characters and comics,
/// whose results leave the feature through [navigator].
///
/// The app builds it from a route (`/search?q=`, discovery_wiring) with the
/// navigator implementation from its wiring; tests pass a mock. It can start
/// from a query alone (plan 01 §4.4).
///
/// Immutable after creation: the flow reads [navigator] and [initialQuery]
/// once, when its scope opens (`provide:` runs once per flow instance). A
/// rebuild with a different navigator keeps the first one; a different
/// [initialQuery] builds a new flow (its `FeatureFlow` is keyed by it), with
/// a fresh scope, state and page.
class DiscoverySearchFlow extends StatelessWidget {
  const DiscoverySearchFlow({
    required this.navigator,
    this.initialQuery,
    super.key,
  });

  final DiscoverySearchNavigator navigator;

  /// Starts the search with this text in the field, searched at once. Null
  /// or blank opens on the recent searches, with the keyboard up.
  final String? initialQuery;

  /// [initialQuery], with a blank one as none (`/search?q=`).
  String? get _query {
    final query = initialQuery;
    return query == null || query.trim().isEmpty ? null : query;
  }

  @override
  Widget build(BuildContext context) => FeatureFlow<DiscoverySearchFlowState>(
    key: ValueKey(_query),
    flowInitializer: const DiscoverySearchDIInitializer(),
    rootImports: discoverySearchRootImports,
    provide: (scope) =>
        scope.registerSingleton<DiscoverySearchNavigator>(navigator),
    localizationsDelegates: const [DiscoverySearchL10n.delegate],
    state: DiscoverySearchFlowState(initialQuery: _query),
    onGeneratePages: (state) => [
      McFlowPage(
        name: 'search',
        arguments: state.initialQuery,
        child: DiscoverySearchPage(initialQuery: state.initialQuery),
      ),
    ],
  );
}
