// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'package:mc_test_steps/src/backend/the_backend_serves.dart';
import './step/i_open_the_greeting.dart';
import 'package:mc_test_steps/src/assertions/i_see.dart';
import 'package:mc_test_steps/src/interaction/i_tap.dart';
import 'package:mc_test_steps/src/assertions/i_dont_see.dart';

void main() {
  group('''Greeting''', () {
    Future<void> bddSetUp(WidgetTester tester) async {
      await theBackendServes(tester, 'greeting.basic');
    }

    mcTestWidgets('''The greeting is shown''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheGreeting(tester);
      await iSee(tester, 'Hello, Bazel');
    }, tags: ['T-0001-AC1', 'smoke']);
    mcTestWidgets('''Tapping the button says goodbye''', (tester) async {
      await bddSetUp(tester);
      await iOpenTheGreeting(tester);
      await iTap(tester, 'Say goodbye');
      await iSee(tester, 'Goodbye');
      await iDontSee(tester, 'Hello, Bazel');
    }, tags: ['T-0029-AC1']);
  });
}
