import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the comics error reads {'Pick at least one comic.'}
///
/// Step 2's error about the picked comics, under the picked count.
Future<void> theComicsErrorReads(WidgetTester tester, String text) async {
  final error = find.byKey(comicsErrorKey);
  expect(error, findsOneWidget, reason: 'step 2 shows an error');
  expect(
    find.descendant(of: error, matching: find.text(text)),
    findsOneWidget,
  );
  expect(
    tester.getSemantics(error).flagsCollection.isLiveRegion,
    isTrue,
    reason: 'the error is announced',
  );
}
