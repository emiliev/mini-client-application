import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/discovery_search_env.dart';

/// Usage: I tap the action of the comics section
///
/// Taps the button in the comics section's header ("Show 20").
Future<void> iTapTheActionOfTheComicsSection(WidgetTester tester) async {
  final action = find.descendant(
    of: find.byKey(searchSectionKey('comic')),
    matching: find.byType(TextButton),
  );
  expect(action, findsOneWidget, reason: 'the comics section has an action');
  await tester.tap(action);
  await mcSettle(tester);
}
