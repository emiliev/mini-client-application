import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the editor shows that it is saving
///
/// Step 3 shows "Saving the list" while the save is in flight.
Future<void> theEditorShowsThatItIsSaving(WidgetTester tester) async {
  final saving = find.byKey(savingKey);
  expect(saving, findsOneWidget, reason: 'step 3 shows that it saves');
  expect(
    find.descendant(of: saving, matching: find.text('Saving the list')),
    findsOneWidget,
  );
}
