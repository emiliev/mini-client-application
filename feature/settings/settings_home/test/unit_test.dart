// Pure logic of settings_home (ADR-0015): the About values from the app's
// config, the profile's wire shape and the account values' equality.
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_config/mc_config.dart';
import 'package:settings_home/src/domain/model/about_info.dart';
import 'package:settings_home/src/domain/model/account_view.dart';

AppConfig _config({String? version}) => AppConfig(
  env: 'e2e',
  backend: BackendConfig(seed: 42, latency: Duration.zero, scenario: 'happy'),
  apiBaseUrl: 'https://mock.invalid/',
  build: '7',
  version: version,
);

void main() {
  test('T-0070-AC1 About reads version, build and the backend seed from the '
      'config', () {
    expect(
      AboutInfo.fromConfig(_config(version: '1.2.3')),
      const AboutInfo(version: '1.2.3', build: '7', seed: 42),
    );
    expect(
      AboutInfo.fromConfig(_config()),
      const AboutInfo(build: '7', seed: 42),
    );
    expect(
      AboutInfo.fromConfig(_config()).version,
      isNull,
      reason: 'no version in the config',
    );
  });

  test('T-0070-AC1 the profile is read from the body of GET v1/me, and a '
      'body that is not a user is a FormatException', () {
    final profile = UserProfile.fromJson({
      'id': 'u-101',
      'email': 'collector@mini-client.test',
      'displayName': 'Cole Collector',
      'favouriteCount': 0,
    });
    expect(
      profile,
      const UserProfile(
        id: 'u-101',
        email: 'collector@mini-client.test',
        displayName: 'Cole Collector',
      ),
    );
    for (final body in <Object?>[
      null,
      'text',
      <String, Object?>{},
      {'id': 'u-1', 'email': 'a@b.c'},
      {'id': 1, 'email': 'a@b.c', 'displayName': 'A'},
    ]) {
      expect(
        () => UserProfile.fromJson(body),
        throwsFormatException,
        reason: '$body',
      );
    }
  });

  test('T-0070-AC2 a signed-in account is named by its profile, else by id, '
      'and equal values are equal', () {
    const profile = UserProfile(id: 'u-1', email: 'a@b.c', displayName: 'Ada');
    expect(const SignedInAccount('u-1', profile: profile).name, 'Ada');
    expect(const SignedInAccount('u-1').name, 'u-1');
    expect(
      const SignedInAccount('u-1', profile: profile),
      const SignedInAccount('u-1', profile: profile),
    );
    expect(const SignedInAccount('u-1'), isNot(const SignedInAccount('u-2')));
    expect(
      const SignedInAccount('u-1'),
      isNot(const SignedInAccount('u-1', profile: profile)),
    );
    expect(const SignedOutAccount(), const SignedOutAccount());
    expect(const SignedOutAccount(), isNot(const SignedInAccount('u-1')));
  });
}
