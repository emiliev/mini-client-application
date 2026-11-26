import 'package:comics_details/src/di/di_initializer.dart';
import 'package:comics_details/src/di/flow_scope.dart';
import 'package:comics_details/src/domain/model/comic_id.dart';
import 'package:comics_details/src/flow/comics_details_flow_state.dart';
import 'package:comics_details/src/l10n/comics_details_l10n.dart';
import 'package:comics_details/src/navigator/comics_details_navigator.dart';
import 'package:comics_details/src/presentation/page/comic_cover_page.dart';
import 'package:comics_details/src/presentation/page/comic_details_page.dart';
import 'package:flutter/widgets.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// The feature's only entry point (R4): one comic's page in sections, whose
/// cover opens full size inside the flow, and whose characters, creators and
/// favourite leave the feature through [navigator].
///
/// The app builds it from a route (`/comics/:id`, publishing_wiring) with the
/// navigator implementation from its wiring; tests pass a mock. It starts
/// from the id alone (plan 01 §4.4).
///
/// Immutable after creation: the flow reads [navigator] and [comicId] once,
/// when its scope opens (`provide:` runs once per flow instance). A rebuild
/// with a different navigator keeps the first one; a different [comicId]
/// builds a new flow (its `FeatureFlow` is keyed by it), with a fresh scope,
/// state and first page.
class ComicsDetailsFlow extends StatelessWidget {
  const ComicsDetailsFlow({
    required this.navigator,
    required this.comicId,
    super.key,
  });

  final ComicsDetailsNavigator navigator;

  /// The comic to show.
  final ComicId comicId;

  @override
  Widget build(BuildContext context) => FeatureFlow<ComicsDetailsFlowState>(
    key: ValueKey(comicId),
    flowInitializer: const ComicsDetailsDIInitializer(),
    rootImports: comicsDetailsRootImports,
    provide: (scope) =>
        scope.registerSingleton<ComicsDetailsNavigator>(navigator),
    localizationsDelegates: const [ComicsDetailsL10n.delegate],
    state: ComicsDetailsFlowState(comicId: comicId),
    onGeneratePages: (state) => [
      McFlowPage(
        name: 'details',
        arguments: state.comicId,
        child: const ComicDetailsPage(),
      ),
      if (state.cover case final comic?)
        McFlowPage(
          name: 'cover',
          arguments: comic.id,
          child: ComicCoverPage(key: ValueKey(comic.id), comic: comic),
        ),
    ],
  );
}
