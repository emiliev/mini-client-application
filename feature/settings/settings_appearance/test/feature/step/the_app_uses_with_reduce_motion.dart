import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the app uses {'dark'} {'compact'} with reduce motion {'on'}
///
/// The app-wide appearance (the root container's, which `McApp` follows)
/// holds these values, spelled as the identity contract spells them. So the
/// choice is the whole app's, not this screen's.
Future<void> theAppUsesWithReduceMotion(
  WidgetTester tester,
  String themeMode,
  String density,
  String onOrOff,
) async {
  final preferences = appearance().snapshot.preferences;
  expect(preferences.themeMode.wire, themeMode);
  expect(preferences.density.wire, density);
  expect(preferences.reduceMotion, onOrOff == 'on');
}
