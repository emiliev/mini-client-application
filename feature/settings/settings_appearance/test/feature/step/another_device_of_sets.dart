import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/settings_appearance_env.dart';

/// Usage: another device of {'collector@mini-client.test'} sets {'density'} {'"compact"'}
///
/// The same user changes the account's copy from another device: a `PATCH`
/// on its current version, straight on the backend engine (the harness
/// records nothing). This device hears nothing of it until it writes.
Future<void> anotherDeviceOfSets(
  WidgetTester tester,
  String email,
  String key,
  String json,
) async {
  final user = fixtureUser(email);
  final version = (await accountOf(tester, email))['version']! as int;
  final response = await tester.runAsync(
    () => McTestSession.current.backend.backend.createDio().patch<Object?>(
      'v1/me/preferences',
      data: {'ifVersion': version, key: jsonDecode(json)},
      options: Options(
        headers: {'Authorization': 'Bearer ${mintAccessToken(user.id, 1)}'},
      ),
    ),
  );
  expect(response?.statusCode, 200, reason: 'the other device wrote');
}
