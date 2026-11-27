import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I choose {'Dark'} in the sheet
///
/// Taps the option labelled [option] among the rows of the open choice sheet
/// (`McChoiceList`). Only the rows count: the sheet's title or any other
/// text with the same words is not an option. Fails when no choice sheet is
/// open, when it has no such option, or when two rows read the same.
Future<void> iChooseInTheSheet(WidgetTester tester, String option) async {
  final target = find
      .descendant(
        of: find.byWidgetPredicate((w) => w is McChoiceList),
        matching: find.text(option),
      )
      .hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'exactly one option "$option" in the open sheet',
  );
  await tester.tap(target);
  await mcSettle(tester);
}
