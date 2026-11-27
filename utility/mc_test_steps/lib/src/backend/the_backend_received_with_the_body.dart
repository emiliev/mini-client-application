import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/src/data_table.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the backend received {'POST /v1/me/lists'} with the body
///   | 'key'      | 'json'             |
///   | 'name'     | '"Weekend reads"'  |
///   | 'comicIds' | '[500060, 500061]' |
///
/// At least one request matched the route, and the JSON body of every one of
/// them has exactly the table's keys, each with the value its `json` cell
/// spells (JSON text, so a string is quoted and a list is a JSON array). The
/// body is compared as decoded JSON, so key order and spacing do not matter;
/// a missing or extra key, or a different value or order in a list, fails.
/// Count the requests with `the backend received {n} requests for {route}`.
Future<void> theBackendReceivedWithTheBody(
  WidgetTester tester,
  String route,
  DataTable table,
) async {
  final matching = [
    for (final r in McTestSession.current.backend.requests)
      if (matchesRequest(r, route)) r,
  ];
  expect(matching, isNotEmpty, reason: 'no request matched "$route"');
  final rows = table.asMaps();
  expect(rows, isNotEmpty, reason: 'the table lists the body');
  final expected = <String, Object?>{
    for (final row in rows)
      row['key']! as String: jsonDecode(row['json']! as String),
  };
  for (final request in matching) {
    // The body as it goes on the wire: the map retrofit built (or the text).
    final body = request.body;
    final actual = jsonDecode(body is String ? body : jsonEncode(body));
    expect(actual, expected, reason: 'the body of $request');
  }
}
