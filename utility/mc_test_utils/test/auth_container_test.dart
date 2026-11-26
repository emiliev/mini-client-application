import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_session/mc_session.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

void main() {
  setUpAll(() => identityFixtureSets.forEach(McFixtureSets.register));

  mcTestWidgets(
    'T-0039-AC5 the test container carries a signed-in user: sign in, then the '
    'bearer reaches the backend',
    (tester) async {
      McTestSession.current.backend.useFixtureSet('identity.default');
      await McTestContainer.initialize(McTestSession.current);

      expect(diContainer<SessionReader>().isSignedIn, isFalse);
      final result = await tester.runAsync(() async {
        final user = await diContainer<AuthApi>().signIn(
          email: 'reader@mini-client.test',
          password: 'marvelous',
        );
        final me = await McTestContainer.dio.get<Map<String, Object?>>(
          '/v1/me',
        );
        return (user.getOrNull()?.id, me.data?['displayName']);
      });

      expect(result, ('u-100', 'Rhea Reader'));
      expect(diContainer<SessionReader>().userId, 'u-100');
      expect(McTestContainer.dio.interceptors.last, isA<AuthInterceptor>());
    },
  );

  mcTestWidgets(
    'T-0039-AC5 a test starts signed out: the previous test signed in',
    (tester) async {
      McTestSession.current.backend.useFixtureSet('identity.default');
      await McTestContainer.initialize(McTestSession.current);

      expect(diContainer<SessionReader>().isSignedIn, isFalse);
      final response = await tester.runAsync(
        () => McTestContainer.dio.get<Object?>(
          '/v1/me',
          options: Options(validateStatus: (_) => true),
        ),
      );
      expect(response!.statusCode, 401);
    },
  );
}
