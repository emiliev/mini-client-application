import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/discovery_search_env.dart';

/// Usage: I filter by {'Comics'}
///
/// Taps the type chip labelled [label] (the section headers carry the same
/// words, so the tap is scoped to the chips).
Future<void> iFilterBy(WidgetTester tester, String label) async {
  final chip = find
      .descendant(of: find.byKey(searchFiltersKey), matching: find.text(label))
      .hitTestable();
  expect(chip, findsOneWidget, reason: 'one "$label" chip');
  await tester.tap(chip);
  await mcSettle(tester);
}
