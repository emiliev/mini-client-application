import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I see the synopsis of comic {501500}
///
/// The fixture comic's description, in full, below its section title.
Future<void> iSeeTheSynopsisOfComic(WidgetTester tester, int id) async {
  final description = find.text(comicRecord(id).description);
  await scrollComicUntilVisible(tester, description);
  expect(description, findsOneWidget);
}
