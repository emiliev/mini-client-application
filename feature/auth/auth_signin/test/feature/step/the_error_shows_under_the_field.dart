import 'package:flutter_test/flutter_test.dart';

import '../util/auth_signin_env.dart';

/// Usage: the error {'Enter your password.'} shows under the field {'Password'}
///
/// The text field labelled [label] shows [text] as its error (the
/// `McTextField`'s error slot, announced as a live region).
Future<void> theErrorShowsUnderTheField(
  WidgetTester tester,
  String text,
  String label,
) async => expectErrorUnder(tester, label, text);
