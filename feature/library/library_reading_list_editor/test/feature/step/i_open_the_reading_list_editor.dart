import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I open the reading list editor
///
/// Enters the feature the way the app does for a new list: through its flow
/// (barrel only), with the navigator passed in the constructor and a result
/// recorder as `onComplete` [tide-nav §3.1].
Future<void> iOpenTheReadingListEditor(WidgetTester tester) async {
  await ensureEditorContainer();
  await initFlow(tester, () => editorTestHost(editorFlowUnderTest()));
  await mcSettle(tester);
}
