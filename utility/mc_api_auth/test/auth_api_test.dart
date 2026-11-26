import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_api_client/mc_api_client.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_prelude/mc_prelude.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_storage/mc_storage.dart';
import 'package:test/test.dart';

import 'rig.dart';

ApiFailure _failure(Result<Object?, ApiFailure> r) =>
    r.fold((_) => fail('expected a failure'), (f) => f);

/// A server whose sign-in answers 200 without tokens.
final class _NoTokensDomain implements MockDomain {
  const _NoTokensDomain();

  @override
  String get name => 'no_tokens';

  @override
  void register(MockRouter router, MockDomainEnvironment environment) {
    router.post(
      '/v1/auth/sign-in',
      (request, context) => const MockResponse.ok({
        'user': {'id': 'u-1', 'email': 'a@b.test', 'displayName': 'A'},
      }),
    );
  }

  @override
  Map<String, MockScenario> get scenarios => const {};
}

void main() {
  late Rig rig;

  setUp(() async => rig = await Rig.create());
  tearDown(() => rig.dispose());

  group('T-0039-AC1 sign-in and sign-out', () {
    test(
      'T-0039-AC1 sign-in starts the session, saves it and publishes',
      () async {
        final result = await rig.api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        await rig.settle();

        final user = result.getOrNull()!;
        expect(user.id, 'u-100');
        expect(user.displayName, 'Rhea Reader');
        expect(rig.session.userId, 'u-100');
        expect(rig.session.accessToken, 'mc-access-u-100-1');
        expect(rig.events, const [SessionChanged(AuthStatus.signedIn)]);
        expect((await Session.restore(rig.store)).userId, 'u-100');
      },
    );

    test(
      'T-0039-AC1 a wrong password is unauthorized and changes nothing',
      () async {
        final result = await rig.api.signIn(
          email: 'reader@mini-client.test',
          password: 'nope',
        );

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.session.isSignedIn, isFalse);
        expect(rig.calls('POST', '/v1/auth/refresh'), 0);
        expect(rig.events, isEmpty);
      },
    );

    test(
      'T-0039-AC1 a failed sign-in keeps the session that was active',
      () async {
        await rig.api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );

        await rig.api.signIn(email: 'reader@mini-client.test', password: 'x');

        expect(rig.session.accessToken, 'mc-access-u-100-1');
      },
    );

    test('T-0039-AC1 a sign-in answer without tokens is malformed', () async {
      final backend = MockBackend(domains: [const _NoTokensDomain()]);
      final dio = createApiDio(adapter: backend.adapter);
      final api = AuthApi(dio, rig.session, rig.session);

      final result = await api.signIn(email: 'a@b.test', password: 'x');

      expect(_failure(result), isA<ApiMalformed>());
      expect(rig.session.isSignedIn, isFalse);
    });

    test('T-0039-AC1 a sign-in answer that is not JSON is malformed', () async {
      rig.backend.failNext(
        'POST',
        '/v1/auth/sign-in',
        const FailureKind.malformed(),
      );

      final result = await rig.api.signIn(
        email: 'reader@mini-client.test',
        password: 'marvelous',
      );

      expect(_failure(result), isA<ApiMalformed>());
    });

    test('T-0039-AC1 a user object that is not valid is malformed', () {
      expect(() => AuthUser.fromJson({'id': 'u'}), throwsFormatException);
      expect(
        AuthUser.fromJson({'id': 'u', 'email': 'e', 'displayName': 'n'}).email,
        'e',
      );
    });

    test('T-0039-AC1 sign-out clears the session at once and revokes the refresh token', () async {
      await rig.api.signIn(
        email: 'reader@mini-client.test',
        password: 'marvelous',
      );
      final refreshToken = rig.session.refreshToken!;

      final result = await rig.api.signOut();
      await rig.settle();

      expect(result.fold((_) => true, (_) => false), isTrue);
      expect(rig.session.isSignedIn, isFalse);
      expect(
        rig.events.map((e) => e.status),
        [AuthStatus.signedIn, AuthStatus.signedOut],
      );
      expect((await Session.restore(rig.store)).isSignedIn, isFalse);
      expect(rig.calls('POST', '/v1/auth/sign-out'), 1);
      // The server revoked it: using it now fails.
      await rig.session.signIn(
        userId: 'u-100',
        tokens: AuthTokens(
          accessToken: expiredAccessToken('u-100'),
          refreshToken: refreshToken,
        ),
      );
      expect(_failure(await rig.api.refresh()), isA<ApiUnauthorized>());
    });

    test(
      'T-0039-AC1 sign-out clears the session even when the server fails',
      () async {
        await rig.api.signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        rig.backend.failNext(
          'POST',
          '/v1/auth/sign-out',
          const FailureKind.offline(),
        );

        final result = await rig.api.signOut();

        expect(_failure(result), isA<ApiOffline>());
        expect(rig.session.isSignedIn, isFalse);
      },
    );

    test(
      'T-0039-AC1 sign-out when signed out sends no token and succeeds',
      () async {
        final result = await rig.api.signOut();

        expect(result.fold((_) => true, (_) => false), isTrue);
        expect(rig.session.isSignedIn, isFalse);
      },
    );
  });

  group('T-0039-AC2 refresh', () {
    test(
      'T-0039-AC2 refresh without a session is unauthorized and sends nothing',
      () async {
        final result = await rig.api.refresh();

        expect(_failure(result), isA<ApiUnauthorized>());
        expect(rig.calls('POST', '/v1/auth/refresh'), 0);
      },
    );

    test('T-0039-AC2 refresh returns the new pair and leaves the session to the caller', () async {
      await rig.startExpiredSession();

      final tokens = (await rig.api.refresh()).getOrNull()!;

      expect(tokens.accessToken, 'mc-access-u-100-1');
      expect(rig.session.accessToken, expiredAccessToken('u-100'));
    });

    test('T-0039-AC2 a refresh answer without tokens is malformed', () async {
      await rig.startExpiredSession();
      rig.backend.failNext(
        'POST',
        '/v1/auth/refresh',
        const FailureKind.malformed(),
      );

      expect(_failure(await rig.api.refresh()), isA<ApiMalformed>());
    });
  });

  group('T-0039-AC5 registration', () {
    test('T-0039-AC5 the initializers register the session, AuthApi and the interceptor last', () async {
      final getIt = GetIt.asNewInstance();
      final backend = MockBackend(
        domains: [const IdentityMockDomain(), ProbeDomain()],
      );
      final dir = rig.dir;
      for (final init in <McDIInitializer>[
        StorageDIInitializer(dir),
        const EventBusDIInitializer(),
        const SessionDIInitializer(),
        McDIInitializer((g, _) {
          g.registerSingleton<Dio>(createApiDio(adapter: backend.adapter));
        }),
        const ApiAuthDIInitializer(),
      ]) {
        await init.init(getIt);
      }

      final api = getIt<AuthApi>();
      await api.signIn(email: 'reader@mini-client.test', password: 'marvelous');
      final echoed = await getIt<Dio>().get<Map<String, Object?>>(
        '/v1/echo-auth',
      );

      expect(getIt<Dio>().interceptors.last, isA<AuthInterceptor>());
      expect(echoed.data, {'authorization': 'Bearer mc-access-u-100-1'});
      await getIt.reset();
    });
  });
}
