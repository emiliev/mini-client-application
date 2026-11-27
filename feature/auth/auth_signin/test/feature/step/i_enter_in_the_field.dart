import 'package:flutter_test/flutter_test.dart';

import '../util/auth_signin_env.dart';

/// Usage: I enter {'reader@mini-client.test'} in the field {'Email'}
///
/// Replaces the text of the field found by its label (in any locale), then
/// moves the focus away so the field is touched.
Future<void> iEnterInTheField(WidgetTester tester, String text, String label) =>
    enterText(tester, label, text);
