import 'package:flutter_test/flutter_test.dart';

import '../util/auth_signin_env.dart';

/// Usage: the field {'Email'} holds {'reader@mini-client.test'}
///
/// The text field labelled [label] holds exactly [text] (`''` for empty).
Future<void> theFieldHolds(
  WidgetTester tester,
  String label,
  String text,
) async => expectFieldText(tester, label, text);
