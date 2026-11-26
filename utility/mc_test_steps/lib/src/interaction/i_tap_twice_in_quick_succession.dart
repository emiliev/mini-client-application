import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I tap {'Add to favourites'} twice in quick succession
///
/// Two taps within one frame, before the first tap's effect is drawn: both
/// reach the widget, so both events reach its bloc. A guard that relies on
/// the redrawn screen (a disabled button) does not stop the second one.
Future<void> iTapTwiceInQuickSuccession(
  WidgetTester tester,
  String label,
) async {
  final target = find.text(label).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one tappable "$label"');
  await tester.tap(target);
  await tester.tap(target);
  await mcSettle(tester);
}
