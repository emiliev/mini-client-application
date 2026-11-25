import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I scroll the characters list until the next page loads
///
/// Real drags, 200 px at a time, until the grid holds more characters than
/// before (the load-more threshold fired and the page arrived).
Future<void> iScrollTheCharactersListUntilTheNextPageLoads(
  WidgetTester tester,
) async {
  final before = charactersShown(tester);
  for (var drags = 0; drags < 100; drags++) {
    await tester.drag(charactersScrollable(), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 100));
    if (charactersShown(tester) > before) {
      await mcSettle(tester);
      return;
    }
  }
  fail('the grid still holds $before characters after 100 drags');
}
