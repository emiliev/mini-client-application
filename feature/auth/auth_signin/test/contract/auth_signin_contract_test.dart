// T-0066-AC1: the repository and the failure mapping against the identity
// fixture's real sign-in answers (the backend's `invalid_credentials` and
// the scenarios), with a real session on a temp directory. Reaches `src/`
// (R7, the contract test).
import 'dart:io';

import 'package:auth_signin/src/domain/model/sign_in_failure.dart';
import 'package:auth_signin/src/domain/repository/auth_signin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';

final class _Rig {
  _Rig(this.dir, this.backend, this.session, this.repository);

  static _Rig start() {
    final dir = Directory.systemTemp.createTempSync('mc_sign_in_contract');
    final backend = MockBackend(domains: const [IdentityMockDomain()]);
    final session = Session.empty(FileStore(dir));
    final auth = AuthApi(backend.createDio(), session, session);
    return _Rig(dir, backend, session, AuthSignInRepository(auth));
  }

  final Directory dir;
  final MockBackend backend;
  final Session session;
  final AuthSignInRepository repository;

  Future<void> dispose() async {
    await session.dispose();
    await dir.delete(recursive: true);
  }
}

void main() {
  late _Rig rig;

  setUp(() => rig = _Rig.start());
  tearDown(() => rig.dispose());

  test('T-0066-AC1 the backend answers wrong credentials with the typed '
      'code invalid_credentials, and nothing is signed in', () async {
    final raw = rig.backend.createDio();
    raw.options.validateStatus = (_) => true;
    final response = await raw.post<Map<String, Object?>>(
      '/v1/auth/sign-in',
      data: {'email': fixtureUsers.first.email, 'password': 'not-it'},
    );

    expect(response.statusCode, 401);
    expect((response.data!['error']! as Map)['code'], 'invalid_credentials');
    expect(response.data!.containsKey('accessToken'), isFalse);
  });

  test('T-0066-AC1 a fixture user signs in: the session starts, the user '
      'is the fixture one', () async {
    final user = fixtureUsers.first;
    final result = await rig.repository.signIn(
      email: user.email,
      password: user.password,
    );

    expect(result.getOrNull()?.id, user.id);
    expect(rig.session.userId, user.id);
    expect(rig.session.isSignedIn, isTrue);
    await rig.session.signOut();
  });

  test('T-0066-AC1 wrong credentials map to InvalidCredentials, and the '
      'session stays signed out', () async {
    final result = await rig.repository.signIn(
      email: fixtureUsers.first.email,
      password: 'not-it',
    );

    final failure = result.fold((_) => null, (f) => f);
    expect(failure, isA<ApiUnauthorized>());
    expect(SignInFailure.of(failure!), isA<InvalidCredentials>());
    expect(rig.session.isSignedIn, isFalse);
  });

  test('T-0066-AC1 an unknown email is InvalidCredentials too', () async {
    final result = await rig.repository.signIn(
      email: 'stranger@mini-client.test',
      password: 'marvelous',
    );

    expect(
      SignInFailure.of(result.fold((_) => null, (f) => f)!),
      isA<InvalidCredentials>(),
    );
    expect(rig.session.isSignedIn, isFalse);
  });

  test(
    'T-0066-AC1 the identity.server_error scenario maps to '
    'SignInUnavailable carrying an ApiServer, and nothing is signed in',
    () async {
      rig.backend.useScenario('identity.server_error');
      final result = await rig.repository.signIn(
        email: fixtureUsers.first.email,
        password: fixtureUsers.first.password,
      );

      final failure = SignInFailure.of(result.fold((_) => null, (f) => f)!);
      expect(failure, isA<SignInUnavailable>());
      expect((failure as SignInUnavailable).cause, isA<ApiServer>());
      expect(rig.session.isSignedIn, isFalse);
    },
  );

  test(
    'T-0066-AC1 the identity.expired_token scenario still signs in: the '
    'session holds the expired access token and the good refresh token',
    () async {
      rig.backend.useScenario('identity.expired_token');
      final user = fixtureUsers.first;
      final result = await rig.repository.signIn(
        email: user.email,
        password: user.password,
      );

      expect(result.getOrNull()?.id, user.id);
      expect(rig.session.accessToken, expiredAccessToken(user.id));
      expect(rig.session.refreshToken, startsWith('mc-refresh-${user.id}-'));
      await rig.session.signOut();
    },
  );
}
