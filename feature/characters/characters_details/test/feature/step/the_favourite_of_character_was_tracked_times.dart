import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the favourite of character {100002} was tracked {1} times
///
/// Exactly [times] `character_favourited` events reached the analytics sink
/// for that character, each with exactly the param `id`. A removal, a failed
/// write and a backed-out sign-in track nothing.
Future<void> theFavouriteOfCharacterWasTrackedTimes(
  WidgetTester tester,
  int id,
  int times,
) async {
  await tester.pump();
  final events = McTestSession.current.analytics.events
      .where((e) => e.name == 'character_favourited')
      .toList();
  expect(
    [for (final e in events) e.params],
    List.generate(times, (_) => {'id': id}),
    reason: 'the character_favourited events tracked',
  );
}
