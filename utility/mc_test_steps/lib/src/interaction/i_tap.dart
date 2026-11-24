import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I tap {'Try again'}
Future<void> iTap(WidgetTester tester, String label) async {
  final target = find.text(label).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one tappable "$label"');
  await tester.tap(target);
  await mcSettle(tester);
}
