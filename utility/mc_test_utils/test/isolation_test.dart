import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import 'support.dart';

class _Clock {
  const _Clock(this.label);
  final String label;
}

/// Each of the two tests asserts a fresh world, then dirties it. Whichever
/// runs second (the order is random under `--test-randomize-ordering-seed`)
/// must still see a fresh one, so the check holds in both orders.
int _dirtied = 0;
int _sawDirtyPredecessor = 0;

Future<void> _assertFreshThenDirty(WidgetTester tester) async {
  final session = McTestSession.current;
  if (_dirtied > 0) {
    _sawDirtyPredecessor++;
  }

  // Fresh DI container: nothing from the previous test.
  expect(diContainer.isRegistered<_Clock>(), isFalse);
  expect(diContainer.isRegistered<Dio>(), isFalse);
  // Fresh backend: no routes, no requests, no failures.
  expect(session.backend.backend.router.routes, isEmpty);
  expect(session.backend.activeFixtureSets, isEmpty);
  expect(session.backend.requests, isEmpty);
  expect(session.backend.hasHolds, isFalse);
  // Fresh platform and surface.
  expect(defaultTargetPlatform, TargetPlatform.iOS);
  expect(tester.view.physicalSize, mcReferenceSurface);
  expect(tester.view.devicePixelRatio, 1);
  expect(session.textScale, 1.0);
  expect(session.themeVariant, McThemeVariant.light);
  expect(session.containerInitialized, isFalse);

  // Dirty everything a test may touch.
  session.backend.useFixtureSet(thingsSet);
  session.backend.fail('GET /v1/things', BackendFailure.timeout);
  session.textScale = 2.0;
  session.themeVariant = McThemeVariant.dark;
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(100, 100);
  await McTestContainer.initialize(
    session,
    externals: [const ExternalDouble<_Clock>(_Clock('registered'))],
  );
  expect(diContainer<_Clock>().label, 'registered');
  expect(diContainer.isRegistered<Dio>(), isTrue);
  // The flow's own request goes through the failure rule; do not pump it.
  _dirtied++;
}

void main() {
  setUpAll(registerThingsSet);

  mcTestWidgets('T-0026-AC2 isolation, first', _assertFreshThenDirty);
  mcTestWidgets('T-0026-AC2 isolation, second', _assertFreshThenDirty);

  tearDownAll(() {
    // Both ran (not a --test_filter subset): the second saw the first's mess
    // gone.
    if (_dirtied == 2) {
      expect(_sawDirtyPredecessor, 1);
    }
  });

  mcTestWidgets('container initialises once per test', (tester) async {
    final session = McTestSession.current;
    await McTestContainer.initialize(session);
    await expectLater(McTestContainer.initialize(session), throwsStateError);
    await expectLater(
      initFlow(
        tester,
        thingsFlow,
        externals: [const ExternalDouble<_Clock>(_Clock('late'))],
      ),
      throwsStateError,
    );
    expect(
      McTestContainer.dio.options.baseUrl,
      McTestContainer.config.apiBaseUrl,
    );
  });

  mcTestWidgets('T-0026-AC2 externals need an explicit, unclaimed type', (
    tester,
  ) async {
    final session = McTestSession.current;
    // Inferred as Object: rejected, and the failed init leaves no mark.
    await expectLater(
      McTestContainer.initialize(
        session,
        externals: [const ExternalDouble(_Clock('untyped'))],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ExternalDouble<_Clock>'),
        ),
      ),
    );
    expect(session.containerInitialized, isFalse);
    // A type the root list owns is rejected, not silently replaced.
    await expectLater(
      McTestContainer.initialize(
        session,
        externals: [ExternalDouble<Dio>(Dio())],
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('duplicates a type the root list'),
        ),
      ),
    );
    expect(session.containerInitialized, isFalse);
    // The retry works, since a failed init publishes nothing.
    await McTestContainer.initialize(
      session,
      externals: [const ExternalDouble<_Clock>(_Clock('ok'))],
    );
    expect(session.containerInitialized, isTrue);
    expect(diContainer<_Clock>().label, 'ok');
  });

  mcTestWidgets('every root service of the production list is present', (
    tester,
  ) async {
    await McTestContainer.initialize(McTestSession.current);
    final session = McTestSession.current;
    expect(McTestContainer.initializers(session, wirings: const []).length, 8);
    expect(diContainer.isRegistered<Dio>(), isTrue);
  });
}
