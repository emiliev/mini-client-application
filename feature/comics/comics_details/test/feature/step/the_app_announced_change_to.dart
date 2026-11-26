import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: the app announced {1} change to {'favourites'}
///
/// Exactly [count] `DataChanged(topic)` events reached a listener on the
/// app's `EventBus` since the comic opened, and no other topic changed.
Future<void> theAppAnnouncedChangeTo(
  WidgetTester tester,
  int count,
  String topic,
) async {
  final changes = announcedChanges();
  expect(
    changes.where((e) => e.topic == topic),
    hasLength(count),
    reason: 'DataChanged("$topic") events',
  );
  expect(
    changes.where((e) => e.topic != topic),
    isEmpty,
    reason: 'no other topic changed',
  );
}
