import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the explainer is open
///
/// The "About themes" page is on top of the flow.
Future<void> theExplainerIsOpen(WidgetTester tester) async {
  expect(find.byKey(aboutBodyKey).hitTestable(), findsOneWidget);
}
