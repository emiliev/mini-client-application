import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_details_env.dart';

/// Usage: I scroll the profile to the end
///
/// Real drags until the profile page sits at its end, so every section has
/// been built and laid out.
Future<void> iScrollTheProfileToTheEnd(WidgetTester tester) async {
  for (var drags = 0; drags < 50; drags++) {
    final position = tester
        .state<ScrollableState>(characterBodyScrollable().first)
        .position;
    if (position.pixels >= position.maxScrollExtent) {
      await mcSettle(tester);
      return;
    }
    await tester.drag(characterBodyScrollable().first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the profile did not reach its end after 50 drags');
}
