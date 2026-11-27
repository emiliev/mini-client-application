import 'package:flutter_test/flutter_test.dart';
import 'package:mc_analytics/mc_analytics.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: no analytics event was tracked
///
/// Nothing but the kit's own events (`mc_session_start`) and screen views
/// reached the analytics sink: no feature event. Use
/// `the screen {name} was tracked` for screens.
Future<void> noAnalyticsEventWasTracked(WidgetTester tester) async {
  await tester.pump();
  final tracked = [
    for (final e in McTestSession.current.analytics.events)
      if (e.name != sessionStartEventName && e.name != screenViewEventName)
        e.name,
  ];
  expect(tracked, isEmpty, reason: 'analytics events that were tracked');
}
