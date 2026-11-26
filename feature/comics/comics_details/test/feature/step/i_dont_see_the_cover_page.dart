import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I don't see the cover page
///
/// The cover page left the flow, and the flow state holds no cover.
Future<void> iDontSeeTheCoverPage(WidgetTester tester) async {
  expect(
    find.byKey(comicCoverPageImageKey, skipOffstage: false),
    findsNothing,
  );
  expect(
    comicsFlowState(tester, find.byKey(comicDetailsBodyKey)).cover,
    isNull,
  );
}
