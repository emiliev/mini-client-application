import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I scroll the characters list to the end
///
/// Real drags until the grid sits at its end with nothing loading: the last
/// page arrived, or a later page failed (its footer offers Retry).
Future<void> iScrollTheCharactersListToTheEnd(WidgetTester tester) async {
  final loadingMore = find.descendant(
    of: find.byKey(charactersGridKey),
    matching: find.byType(McLoading),
  );
  for (var drags = 0; drags < 100; drags++) {
    final position = charactersScrollPosition(tester);
    if (position.pixels >= position.maxScrollExtent &&
        loadingMore.evaluate().isEmpty) {
      await mcSettle(tester);
      return;
    }
    await tester.drag(charactersScrollable(), const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the characters list did not reach its end after 100 drags');
}
