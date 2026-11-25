import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I tap {'Amber Alchemist'} and {'Amber Bard'} in quick succession
///
/// Two tiles tapped within one frame, before the first tap's preview exists:
/// both taps reach the list, so both preview events reach the bloc. (Once the
/// preview route is pushed, its modal barrier takes every tap until it
/// settles, so this is the window where a second tap can land.)
Future<void> iTapAndInQuickSuccession(
  WidgetTester tester,
  String first,
  String second,
) async {
  final a = find.text(first).hitTestable();
  final b = find.text(second).hitTestable();
  expect(a, findsOneWidget, reason: 'exactly one tappable "$first"');
  expect(b, findsOneWidget, reason: 'exactly one tappable "$second"');

  await tester.tap(a);
  await tester.tap(b);
  await mcSettle(tester);
}
