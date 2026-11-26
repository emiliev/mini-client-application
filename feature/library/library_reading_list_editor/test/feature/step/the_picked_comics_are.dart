import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the picked comics are
///   | 'title'               |
///   | 'Amber Chronicles #1' |
///
/// Step 2's picked chips, in the order they were picked.
Future<void> thePickedComicsAre(WidgetTester tester, DataTable table) async {
  final chips = tester.widgetList<McChip>(
    find.descendant(
      of: find.byKey(pickedComicsKey),
      matching: find.byType(McChip),
    ),
  );
  expect(
    [for (final chip in chips) chip.label],
    titlesOf(table),
    reason: 'the picked comics',
  );
}
