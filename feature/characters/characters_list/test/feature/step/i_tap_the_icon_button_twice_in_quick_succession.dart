import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I tap the icon button {'Search characters'} twice in quick succession
///
/// Two taps within one frame, before the first tap's effect is drawn: both
/// reach the button, so both events reach its bloc.
Future<void> iTapTheIconButtonTwiceInQuickSuccession(
  WidgetTester tester,
  String label,
) async {
  final target = find.byTooltip(label).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one icon button "$label"');
  await tester.tap(target);
  await tester.tap(target);
  await mcSettle(tester);
}
