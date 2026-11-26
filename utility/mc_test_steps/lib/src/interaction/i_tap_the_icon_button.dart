import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I tap the icon button {'Clear search'}
///
/// An icon-only button has no text to tap; it is found by its tooltip, which
/// carries its accessible name (`McIconButton` sets both from one label).
Future<void> iTapTheIconButton(WidgetTester tester, String label) async {
  final target = find.byTooltip(label).hitTestable();
  expect(target, findsOneWidget, reason: 'exactly one icon button "$label"');
  await tester.tap(target);
  await mcSettle(tester);
}
