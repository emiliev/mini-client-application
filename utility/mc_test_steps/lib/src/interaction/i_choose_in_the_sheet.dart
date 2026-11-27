import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I choose {'Dark'} in the sheet
///
/// Taps the option labelled [option] inside the open `McSheet` (a choice
/// sheet). Fails when no sheet is open or the sheet has no such option.
Future<void> iChooseInTheSheet(WidgetTester tester, String option) async {
  final target = find
      .descendant(of: find.byType(McSheet), matching: find.text(option))
      .hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'exactly one option "$option" in the open sheet',
  );
  await tester.tap(target);
  await mcSettle(tester);
}
