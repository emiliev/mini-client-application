import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/data_table.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the analytics event {'comic_opened'} was tracked with
///   | 'key' | 'json'   |
///   | 'id'  | '501500' |
///   | 'new' | 'true'   |
///
/// At least one event of that name reached the analytics sink with exactly
/// the table's params, each value as its `json` cell spells it (JSON text, so
/// a string is quoted: `'"Spider"'`; `1` is an int and `1.0` a double). A
/// missing, extra or differently typed param fails.
Future<void> theAnalyticsEventWasTrackedWith(
  WidgetTester tester,
  String name,
  DataTable table,
) async {
  await tester.pump();
  final rows = table.asMaps();
  expect(rows, isNotEmpty, reason: 'the table lists the params');
  final expected = <String, Object?>{
    for (final row in rows)
      row['key']! as String: jsonDecode(row['json']! as String),
  };
  final events = McTestSession.current.analytics.events
      .where((e) => e.name == name)
      .toList();
  expect(events, isNotEmpty, reason: 'no analytics event "$name" was tracked');
  expect(
    events.any((e) => mapEquals<String, Object?>(e.params, expected)),
    isTrue,
    reason:
        'no "$name" event had exactly these params; got '
        '${events.map((e) => e.params).toList()}',
  );
}
