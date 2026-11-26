import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the cover
///
/// Drags the details page back to its top (the header is the first
/// section), then taps the header's cover image.
Future<void> iTapTheCover(WidgetTester tester) async {
  for (var drags = 0; drags < 50; drags++) {
    final position = tester
        .state<ScrollableState>(comicBodyScrollable().first)
        .position;
    if (position.pixels <= position.minScrollExtent) {
      break;
    }
    await tester.drag(comicBodyScrollable().first, const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await mcSettle(tester);
  final cover = find.byKey(comicCoverKey).hitTestable();
  expect(cover, findsOneWidget, reason: 'the cover is tappable');
  await tester.tap(cover);
  await mcSettle(tester);
}
