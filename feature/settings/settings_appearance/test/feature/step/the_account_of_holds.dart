import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../util/settings_appearance_env.dart';

/// Usage: the account of {'collector@mini-client.test'} holds {'themeMode'} {'"dark"'}
///
/// The backend engine's copy of that user's preferences has [key] equal to
/// the JSON [json] (read with a minted token: the harness records nothing).
Future<void> theAccountOfHolds(
  WidgetTester tester,
  String email,
  String key,
  String json,
) async {
  final account = await accountOf(tester, email);
  expect(account[key], jsonDecode(json), reason: "$email's $key");
}
