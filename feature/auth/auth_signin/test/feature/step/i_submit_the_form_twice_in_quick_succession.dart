import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';

import '../util/auth_signin_env.dart';

/// Usage: I submit the form twice in quick succession
///
/// Two taps on the submit button within one frame, before the first tap's
/// effect is drawn: both reach the widget, so both events reach the bloc. A
/// guard that relies on the redrawn screen (a disabled button) does not stop
/// the second one.
Future<void> iSubmitTheFormTwiceInQuickSuccession(WidgetTester tester) async {
  final button = find.byKey(McFormScaffold.submitKey);
  expect(button, findsOneWidget, reason: 'the form has one submit button');
  await tester.tap(button);
  await tester.tap(button);
  await settleSignIn(tester);
}
