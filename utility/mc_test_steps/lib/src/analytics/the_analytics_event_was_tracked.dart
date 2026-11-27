import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the analytics event {'comic_opened'} was tracked
///
/// At least one event of that name reached the analytics sink (so consent was
/// granted and the facade accepted it). Check its params with
/// `the analytics event {name} was tracked with` and a table.
Future<void> theAnalyticsEventWasTracked(
  WidgetTester tester,
  String name,
) async {
  // Delivery is a microtask after `track`; let it run.
  await tester.pump();
  final events = McTestSession.current.analytics.events;
  expect(
    events.where((e) => e.name == name),
    isNotEmpty,
    reason:
        'no analytics event "$name" was tracked; delivered: '
        '${[for (final e in events) e.name]}',
  );
}
