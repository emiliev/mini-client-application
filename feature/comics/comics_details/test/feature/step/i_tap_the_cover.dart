import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cover
///
/// The header's cover image.
Future<void> iTapTheCover(WidgetTester tester) async {
  final cover = find.byKey(comicCoverKey).hitTestable();
  expect(cover, findsOneWidget, reason: 'the cover is tappable');
  await tester.tap(cover);
  await mcSettle(tester);
}
