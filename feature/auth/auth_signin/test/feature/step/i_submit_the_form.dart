import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_forms/mc_ds_forms.dart';

import '../util/auth_signin_env.dart';

/// Usage: I submit the form
///
/// Taps the form's submit button. Found by its key, because the app bar's
/// title and the button read the same ("Sign in"). Then the app's real file
/// I/O (the session's save) runs to the end, as a sign-in's does in the app
/// (`settleSignIn`).
Future<void> iSubmitTheForm(WidgetTester tester) async {
  final button = find.byKey(McFormScaffold.submitKey);
  expect(button, findsOneWidget, reason: 'the form has one submit button');
  await tester.tap(button);
  await settleSignIn(tester);
}
