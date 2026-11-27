import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the preferences writes were {'[{"ifVersion": 0, "themeMode": "dark"}]'}
///
/// The bodies of every `PATCH /v1/me/preferences` that reached the backend,
/// in order, as a JSON list: exactly these, no more and no fewer.
Future<void> thePreferencesWritesWere(WidgetTester tester, String json) async {
  final sent = [
    for (final r in McTestSession.current.backend.requests)
      if (r.method == 'PATCH' && r.path == '/v1/me/preferences')
        jsonDecode(r.body is String ? r.body! as String : jsonEncode(r.body)),
  ];
  expect(sent, jsonDecode(json));
}
