import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: the app announced {1} change to {'readingLists'}
///
/// `DataChanged(topic)` was published on the bus exactly [count] times.
Future<void> theAppAnnouncedChangeTo(
  WidgetTester tester,
  int count,
  String topic,
) async => expect(
  announcedChanges().where((c) => c.topic == topic),
  hasLength(count),
  reason: 'DataChanged($topic) announcements',
);
