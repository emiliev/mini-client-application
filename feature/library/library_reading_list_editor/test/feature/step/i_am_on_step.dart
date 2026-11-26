import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I am on step {2}
///
/// The flow shows that step's page on top (its state's deepest step), and
/// the step bar reads "Step n of 3".
Future<void> iAmOnStep(WidgetTester tester, int step) async {
  expect(
    editorFlowState(
      tester,
      find.byKey(detailsBodyKey, skipOffstage: false),
    ).step,
    step - 1,
    reason: 'the flow is on step $step',
  );
  expect(find.text('Step $step of 3'), findsOneWidget);
}
