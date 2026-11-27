import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I go back
///
/// Taps the top page's back button (`McFlowBackButton` draws a
/// `BackButton`).
Future<void> iGoBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).hitTestable().last);
  await mcSettle(tester);
}
