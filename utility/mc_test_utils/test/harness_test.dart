import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'support.dart';

void main() {
  setUpAll(registerThingsSet);

  mcTestWidgets('T-0026-AC1 an endpoint with no fixture set fails by route', (
    tester,
  ) async {
    final session = McTestSession.current;
    await initFlow(tester, thingsFlow);
    await mcSettle(tester);

    // The app saw a 404 and showed its error state...
    expect(find.text('error'), findsOneWidget);
    // ...and the harness names the route.
    expect(session.backend.unmatched, ['GET /v1/things']);
    expect(
      session.backend.verify,
      throwsA(
        isA<TestFailure>().having(
          (f) => f.message,
          'message',
          allOf(
            contains('Unmatched request GET /v1/things'),
            contains('active: none'),
          ),
        ),
      ),
    );
    // The wrapper reports it too, also when the body threw first.
    await expectLater(
      session.guard(() async => throw StateError('boom')),
      throwsA(
        isA<TestFailure>().having(
          (f) => f.message,
          'message',
          allOf(
            contains('Unmatched request GET /v1/things'),
            contains('The test body failed: Bad state: boom'),
          ),
        ),
      ),
    );
    await expectLater(session.guard(() async {}), throwsA(isA<TestFailure>()));
    // Provoked on purpose: acknowledge it so this test can pass.
    expect(session.backend.takeUnmatched(), ['GET /v1/things']);
    await session.guard(() async {});
    await expectLater(
      session.guard(() async => throw StateError('plain')),
      throwsA(isA<StateError>()),
    );
  });

  mcTestWidgets('fixture set answers; recorded requests and routes', (
    tester,
  ) async {
    final backend = McTestSession.current.backend..useFixtureSet(thingsSet);
    backend.useFixtureSet(thingsSet); // idempotent
    expect(backend.activeFixtureSets, {thingsSet});
    await initFlow(tester, thingsFlow);
    await mcSettle(tester);

    expect(find.text('alpha,beta'), findsOneWidget);
    final request = backend.requests.single;
    expect(request.routeKey, 'GET /v1/things');
    expect(request.toString(), 'GET /v1/things');
    expect(matchesRequest(request, 'GET /v1/things'), isTrue);
    expect(matchesRequest(request, 'get /v1/things?offset=2'), isFalse);
    expect(matchesRequest(request, 'POST /v1/things'), isFalse);
    expect(matchesRequest(request, '* /v1/things'), isTrue);
    expect(
      RecordedRequest(
        method: 'GET',
        path: '/v1/x',
        query: const {'a': '1'},
      ).toString(),
      'GET /v1/x?a=1',
    );
    expect(backend.unmatched, isEmpty);
  });

  mcTestWidgets('route syntax and unknown names are rejected', (tester) async {
    final backend = McTestSession.current.backend;
    expect(() => backend.useFixtureSet('nope'), throwsArgumentError);
    expect(
      () => backend.fail('/v1/things', BackendFailure.timeout),
      throwsA(isA<ArgumentError>()),
    );
    expect(() => backend.release('GET /v1/things'), throwsStateError);
    expect(McFixtureSets.names, contains(thingsSet));
    for (final failure in BackendFailure.values) {
      expect(failure.kind, isA<FailureKind>());
    }
  });

  mcTestWidgets('T-0026-AC3 fail(times: 1) fails once, the retry succeeds', (
    tester,
  ) async {
    final backend = McTestSession.current.backend
      ..useFixtureSet(thingsSet)
      ..fail('GET /v1/things', BackendFailure.serverError, times: 1);
    await initFlow(tester, thingsFlow);
    await mcSettle(tester);

    expect(find.text('alpha,beta'), findsOneWidget);
    expect(backend.requests.map((r) => r.routeKey), [
      'GET /v1/things',
      'GET /v1/things',
    ]);
    expect(backend.backend.recentTraffic.map((t) => t.status), [500, 200]);
  });

  mcTestWidgets('fail() with a query subset only fails matching requests', (
    tester,
  ) async {
    final backend = McTestSession.current.backend
      ..useFixtureSet(thingsSet)
      ..fail('GET /v1/things?page=2', BackendFailure.offline);
    await initFlow(tester, thingsFlow);
    await mcSettle(tester);
    expect(find.text('alpha,beta'), findsOneWidget);
    expect(backend.backend.recentTraffic.single.status, 200);
  });

  mcTestWidgets('T-0026-AC3 hold keeps loading observable until release', (
    tester,
  ) async {
    final backend = McTestSession.current.backend
      ..useFixtureSet(thingsSet)
      ..hold('GET /v1/things');
    await initFlow(tester, thingsFlow);
    await mcSettle(tester);

    expect(find.text('loading'), findsOneWidget);
    expect(backend.hasHolds, isTrue);
    expect(backend.requests, hasLength(1));

    await backend.release('GET /v1/things');
    await mcSettle(tester);
    expect(backend.hasHolds, isFalse);
    expect(find.text('alpha,beta'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
  });

  mcTestWidgets('an unreleased hold fails the test', (tester) async {
    final session = McTestSession.current;
    session.backend.hold('GET /v1/things?x=1');
    await expectLater(
      session.guard(() async {}),
      throwsA(
        isA<TestFailure>().having(
          (f) => f.message,
          'message',
          contains('Held request never released: GET /v1/things'),
        ),
      ),
    );
    session.backend.clearHolds();
    await session.guard(() async {});
  });

  mcTestWidgets('MockMonitoring records; createMockMonitoring is fresh', (
    tester,
  ) async {
    final monitoring = createMockMonitoring();
    await monitoring.log('hello', level: LogLevel.warning);
    await monitoring.trackEvent('opened', attributes: {'a': 1});
    await monitoring.recordError(StateError('x'), null);
    expect(monitoring.entries, hasLength(3));
    expect(monitoring.logs.single.message, 'hello');
    expect(monitoring.events.single.name, 'opened');
    expect(monitoring.errors.single.error, isA<StateError>());
    monitoring.clear();
    expect(monitoring.entries, isEmpty);
    expect(createMockMonitoring().entries, isEmpty);
  });

  test('T-0026-AC1 session is unavailable outside mcTestWidgets', () {
    expect(McTestSession.isActive, isFalse);
    expect(() => McTestSession.current, throwsStateError);
  });

  test('tags: T-/MC- tags go into the name, the rest stay Dart tags', () {
    final (name, dartTags) = McTestSession.splitTags('opens', [
      '@T-0123-AC1',
      'MC-chronicle-02',
      '@golden',
    ]);
    expect(name, 'opens [T-0123-AC1 MC-chronicle-02]');
    expect(dartTags, ['golden']);
    expect(McTestSession.splitTags('plain', null).$1, 'plain');
  });

  testWidgets('mcSettle outside a session just settles', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await mcSettle(tester);
  });
}
