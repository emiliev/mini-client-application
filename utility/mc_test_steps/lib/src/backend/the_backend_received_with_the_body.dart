import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/data_table.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend received {'POST /v1/me/lists'} with the body
///   | 'key'      | 'json'             |
///   | 'name'     | '"Weekend reads"'  |
///   | 'comicIds' | '[500060, 500061]' |
///
/// Exactly one request matched the route, and its JSON body has exactly the
/// table's keys, each with the value its `json` cell spells (JSON text, so
/// a string is quoted and a list is a JSON array). The body is compared as
/// decoded JSON, so key order and spacing do not matter; a missing or extra
/// key, or a different value or order in a list, fails.
Future<void> theBackendReceivedWithTheBody(
  WidgetTester tester,
  String route,
  DataTable table,
) async {
  final matching = [
    for (final r in McTestSession.current.backend.requests)
      if (matchesRequest(r, route)) r,
  ];
  expect(matching, hasLength(1), reason: 'one request matched "$route"');
  final rows = table.asMaps();
  expect(rows, isNotEmpty, reason: 'the table lists the body');
  final expected = <String, Object?>{
    for (final row in rows)
      row['key']! as String: jsonDecode(row['json']! as String),
  };
  final body = matching.single.body;
  // The body as it went on the wire: the map retrofit built (or the text).
  final actual = jsonDecode(body is String ? body : jsonEncode(body));
  expect(actual, expected, reason: 'the body of "$route"');
}
