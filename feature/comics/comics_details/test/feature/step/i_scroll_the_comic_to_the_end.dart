import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I scroll the comic to the end
///
/// Real drags until the details page sits at its end, so every section has
/// been built and laid out.
Future<void> iScrollTheComicToTheEnd(WidgetTester tester) async {
  for (var drags = 0; drags < 50; drags++) {
    final position = tester
        .state<ScrollableState>(comicBodyScrollable().first)
        .position;
    if (position.pixels >= position.maxScrollExtent) {
      await mcSettle(tester);
      return;
    }
    await tester.drag(comicBodyScrollable().first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the comic did not reach its end after 50 drags');
}
