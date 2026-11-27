import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_overlays/mc_ds_overlays.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I cancel the dialog
///
/// Taps the cancel button of the open `showMcConfirm` dialog. Fails when
/// there is no such dialog (or two).
Future<void> iCancelTheDialog(WidgetTester tester) async {
  final target = find.byKey(mcCancelButtonKey).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one confirm dialog is open');
  await tester.tap(target);
  await mcSettle(tester);
}
