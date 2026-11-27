import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the screen {'characters_list'} was tracked
///
/// The route observer (or `Analytics.screen`) reported that screen: a
/// `mc_screen_view` with that `screen_name` reached the analytics sink.
Future<void> theScreenWasTracked(WidgetTester tester, String name) async {
  await tester.pump();
  final screens = McTestSession.current.analytics.screens;
  expect(
    screens,
    contains(name),
    reason: 'screen "$name" was not tracked; tracked: $screens',
  );
}
