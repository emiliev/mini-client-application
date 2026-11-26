import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I tap {'Amber Frontier #1'} in the picked comics
///
/// Taps that comic's chip in step 2 (a picked chip deselects: the comic
/// leaves the list).
Future<void> iTapInThePickedComics(WidgetTester tester, String title) async {
  final chip = find.descendant(
    of: find.byKey(pickedComicsKey),
    matching: find.text(title),
  );
  expect(chip, findsOneWidget, reason: '"$title" is picked');
  await tester.tap(chip.hitTestable());
  await mcSettle(tester);
}
