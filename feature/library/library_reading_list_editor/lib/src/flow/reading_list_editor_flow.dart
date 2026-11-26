import 'package:flutter/widgets.dart';
import 'package:library_reading_list_editor/src/di/di_initializer.dart';
import 'package:library_reading_list_editor/src/di/flow_scope.dart';
import 'package:library_reading_list_editor/src/domain/model/reading_list_id.dart';
import 'package:library_reading_list_editor/src/flow/reading_list_editor_flow_state.dart';
import 'package:library_reading_list_editor/src/l10n/reading_list_editor_l10n.dart';
import 'package:library_reading_list_editor/src/navigator/reading_list_editor_navigator.dart';
import 'package:library_reading_list_editor/src/presentation/page/comics_page.dart';
import 'package:library_reading_list_editor/src/presentation/page/details_page.dart';
import 'package:library_reading_list_editor/src/presentation/page/review_page.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

/// The feature's only entry point (R4): a three-step wizard that creates a
/// reading list, or edits the one [editing] names, and **ends with a
/// result**.
///
/// The flow result (plan 01 §4.3, first used here; the FW archetype's shape):
/// - When the wizard saves, the flow completes with the saved list's id:
///   [onComplete] is called once with it.
/// - When the flow ends without saving (the user declined to sign in, or
///   closed the editor after the session changed), [onComplete] is called
///   once with null.
/// - When the user leaves by Back from step 1, the app's route is popped and
///   [onComplete] is not called; the route's own pop gives its caller null.
///
/// The app builds it from a route (`/me/lists/new`, `/me/lists/:id/edit`,
/// library_wiring), whose [onComplete] pops that route with the id, so
/// whoever pushed the route awaits the result. Tests pass a recorder. It
/// starts from the id alone (plan 01 §4.4).
///
/// Immutable after creation: the flow reads [navigator] and [editing] once,
/// when its scope opens. A different [editing] builds a new flow (its
/// `FeatureFlow` is keyed by it).
class ReadingListEditorFlow extends StatelessWidget {
  const ReadingListEditorFlow({
    required this.navigator,
    required this.onComplete,
    this.editing,
    super.key,
  });

  final ReadingListEditorNavigator navigator;

  /// The list to edit; null creates a new one.
  final ReadingListId? editing;

  /// The flow's result: the saved list's id, or null when it ended without
  /// saving. Called at most once.
  final ValueChanged<ReadingListId?> onComplete;

  @override
  Widget build(BuildContext context) =>
      FeatureFlow<ReadingListEditorFlowState>(
        key: ValueKey(editing),
        flowInitializer: const ReadingListEditorDIInitializer(),
        rootImports: readingListEditorRootImports,
        provide: (scope) =>
            scope.registerSingleton<ReadingListEditorNavigator>(navigator),
        localizationsDelegates: const [ReadingListEditorL10n.delegate],
        state: ReadingListEditorFlowState(editing: editing),
        onComplete: (result) => onComplete(result as ReadingListId?),
        // One page per step, pushed in order, so a back gesture on a later
        // step returns to the step before it.
        onGeneratePages: (state) => [
          const McFlowPage(name: 'details', child: ReadingListDetailsPage()),
          if (state.step >= 1)
            const McFlowPage(name: 'comics', child: ReadingListComicsPage()),
          if (state.step >= 2)
            const McFlowPage(name: 'review', child: ReadingListReviewPage()),
        ],
      );
}
