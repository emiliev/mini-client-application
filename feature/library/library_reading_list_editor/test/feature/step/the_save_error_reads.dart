import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the save error reads {'The server had a problem. Please try again later.'}
///
/// Step 3's inline error after a failed save: its title and [message].
Future<void> theSaveErrorReads(WidgetTester tester, String message) async {
  final error = find.byKey(saveErrorKey);
  expect(error, findsOneWidget, reason: 'step 3 shows the save error');
  for (final text in ['The list could not be saved', message]) {
    expect(
      find.descendant(of: error, matching: find.text(text)),
      findsOneWidget,
    );
  }
}
