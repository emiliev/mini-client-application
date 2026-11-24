// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:mc_test_steps/mc_test_steps.dart' as bdd;
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'package:mc_test_steps/mc_test_steps.dart';

import './step/i_open_the_greeting.dart';

void main() {
  group('''Greeting texts''', () {
    mcTestWidgets('''Every label is on screen''', (tester) async {
      await theBackendServes(tester, 'greeting.basic');
      await iOpenTheGreeting(tester);
      await iSeeTheTexts(
        tester,
        const bdd.DataTable([
          ['text'],
          ['Hello, Bazel'],
          ['Say goodbye'],
        ]),
      );
    }, tags: ['T-0029-AC4']);
  });
}
