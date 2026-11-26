import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I open the reading list editor for {'l-1'}
///
/// Enters the feature in edit mode, as the app does for `/me/lists/:id/edit`.
Future<void> iOpenTheReadingListEditorFor(WidgetTester tester, String id) async {
  await ensureEditorContainer();
  await initFlow(
    tester,
    () => editorTestHost(editorFlowUnderTest(editing: id)),
  );
  await mcSettle(tester);
}
