import 'package:bdd_sample/bdd_sample.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I open the greeting
Future<void> iOpenTheGreeting(WidgetTester tester) async {
  await initFlow(tester, greetingFlow);
  await mcSettle(tester);
}
