import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the settings changes tracked are {'theme_mode=dark, density=compact'}
///
/// Every `settings_changed` event that reached analytics, in order, as
/// `setting=value`: exactly these (an empty string: none).
Future<void> theSettingsChangesTrackedAre(
  WidgetTester tester,
  String expected,
) async {
  await tester.pump();
  final tracked = [
    for (final e in McTestSession.current.analytics.events)
      if (e.name == 'settings_changed')
        '${e.params['setting']}=${e.params['value']}',
  ];
  expect(tracked, [
    for (final part in expected.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ]);
}
