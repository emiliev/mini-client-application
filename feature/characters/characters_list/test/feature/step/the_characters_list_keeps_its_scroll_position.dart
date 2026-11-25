import 'package:flutter_test/flutter_test.dart';

import '../util/characters_list_env.dart';

/// Usage: the characters list keeps its scroll position
///
/// The grid is where `I scroll the characters list until I see` left it, and
/// that was not the top.
Future<void> theCharactersListKeepsItsScrollPosition(
  WidgetTester tester,
) async {
  final remembered = rememberedScrollOffset();
  expect(remembered, isNotNull, reason: 'no earlier step scrolled the list');
  expect(remembered, greaterThan(0), reason: 'the list was scrolled down');
  expect(charactersScrollPosition(tester).pixels, remembered);
}
