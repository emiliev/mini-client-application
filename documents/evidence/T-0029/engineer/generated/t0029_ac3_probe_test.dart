// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart' as bdd;
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import './step/i_open_the_greeting.dart';
import './step/i_wave_times.dart';
import './step/the_greeting_rows_are.dart';

void main() {
  group('''New behaviour''', () {
    mcTestWidgets('''Two new steps and two known ones''', (tester) async {
      await theBackendServes(tester, 'greeting.basic');
      await iOpenTheGreeting(tester);
      await iWaveTimes(tester, 2);
      await theGreetingRowsAre(
        tester,
        const bdd.DataTable([
          ['text'],
          ['Hi'],
        ]),
      );
    });
  });
}
