import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I confirm the dialog
///
/// Taps the confirm button of the open `showMcConfirm` dialog. Fails when
/// there is no such dialog (or two).
Future<void> iConfirmTheDialog(WidgetTester tester) async {
  final target = find.byKey(mcConfirmButtonKey).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one confirm dialog is open');
  await tester.tap(target);
  await mcSettle(tester);
}
