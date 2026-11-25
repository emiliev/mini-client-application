import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I scroll the characters list until I see {'Amber Herald'}
///
/// Drags the grid until [name] is on screen, then remembers the scroll
/// position for `the characters list keeps its scroll position`.
Future<void> iScrollTheCharactersListUntilISee(
  WidgetTester tester,
  String name,
) async {
  await tester.scrollUntilVisible(
    find.text(name),
    200,
    scrollable: charactersScrollable(),
  );
  await mcSettle(tester);
  rememberScrollOffset(charactersScrollPosition(tester).pixels);
}
