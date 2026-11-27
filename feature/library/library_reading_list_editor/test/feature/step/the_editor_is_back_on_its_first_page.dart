import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the editor is back on its first page
///
/// The flow has only its root page open (step 1's page, which also shows
/// the editor's states outside the wizard).
Future<void> theEditorIsBackOnItsFirstPage(WidgetTester tester) async {
  expect(editorFlowState(tester, editorAnchor()).step, 0);
  expect(find.byType(Scaffold), findsOneWidget, reason: 'one page on top');
}
