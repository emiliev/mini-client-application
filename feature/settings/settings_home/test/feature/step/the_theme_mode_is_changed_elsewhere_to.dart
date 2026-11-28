import 'package:flutter_test/flutter_test.dart';
import 'package:mc_appearance/mc_appearance.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_home_env.dart';

/// Usage: the theme mode is changed elsewhere to {'dark'}
///
/// The Appearance page (or anything else) changes the app-wide theme mode
/// through the appearance, by its wire name (`system`, `light`, `dark`). The
/// device copy is saved before the call returns (ADR-0013).
Future<void> theThemeModeIsChangedElsewhereTo(
  WidgetTester tester,
  String wire,
) async {
  final mode = AppearanceThemeMode.fromWire(wire);
  expect(mode, isNotNull, reason: '"$wire" is a theme mode');
  await tester.runAsync(() => appearance().change(themeMode: mode));
  await mcSettle(tester);
}
