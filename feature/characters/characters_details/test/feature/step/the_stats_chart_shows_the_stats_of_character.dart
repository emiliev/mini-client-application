import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_charts/mc_ds_charts.dart';

import '../util/characters_details_env.dart';

/// Usage: the stats chart shows the stats of character {100002}
///
/// One horizontal bar per stat of the fixture character, in the order
/// intelligence, strength, speed, durability, energy, combat, each with the
/// English label and the fixture's value (an integer from 1 to 100).
Future<void> theStatsChartShowsTheStatsOfCharacter(
  WidgetTester tester,
  int id,
) async {
  final chart = find.byKey(characterStatsKey);
  await scrollCharacterUntilVisible(tester, chart);
  final shown = tester.widget<McBarChart>(chart);
  final stats = characterWithId(id).stats;
  expect(shown.orientation, Axis.horizontal);
  expect(shown.data, [
    McBarDatum(label: 'Intelligence', value: stats['intelligence']!.toDouble()),
    McBarDatum(label: 'Strength', value: stats['strength']!.toDouble()),
    McBarDatum(label: 'Speed', value: stats['speed']!.toDouble()),
    McBarDatum(label: 'Durability', value: stats['durability']!.toDouble()),
    McBarDatum(label: 'Energy', value: stats['energy']!.toDouble()),
    McBarDatum(label: 'Combat', value: stats['combat']!.toDouble()),
  ]);
}
