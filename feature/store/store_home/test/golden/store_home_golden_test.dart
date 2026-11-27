// Screen goldens of the flow (plan 05 §1.2), entered through the barrel: the
// store home loaded in the 4 themes, its lower sections, every section
// loading, failed and empty, the category page, and the pseudo-locale at 2x.
// Real Inter fonts and the bundled fixture art, on the 402x874 reference
// surface.
//
//   tool/bazelw run //feature/store/store_home:golden_test -- --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_tokens/mc_ds_tokens.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../feature/util/store_home_env.dart';

final List<String> _art = [
  for (var i = 0; i < placeholderSets['characters']!; i++)
    'packages/mc_fixtures_media/assets/characters/'
        '${i.toString().padLeft(3, '0')}.png',
];

/// Signs the reader in with two lines in the cart, then opens the store
/// with every placeholder picture decoded first, so the first frame draws
/// the art (F-0030).
Future<void> _open(
  WidgetTester tester, {
  bool signedIn = true,
  String? category,
}) async {
  final session = McTestSession.current;
  session.backend
    ..useFixtureSet('commerce.default')
    ..useFixtureSet('identity.default');
  await ensureStoreContainer();
  if (signedIn) {
    await signIn(tester, 'reader@mini-client.test');
    await putInCart(tester, 'reader@mini-client.test', 500060, 2);
    await putInCart(tester, 'reader@mini-client.test', 500120, 1);
  }
  final bundle = McFixtureAssetBundle();
  await mcPrecacheFixtureImages(tester, bundle, _art);
  await initFlow(
    tester,
    () => storeTestHost(storeFlowUnderTest(category: category), bundle: bundle),
  );
  await mcSettle(tester);
}

Future<void> _expectGolden(String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('goldens/$name.png'),
);

void main() {
  setUpAll(bddSetUpAll);

  for (final variant in McThemeVariant.values) {
    mcTestWidgets('T-0056-AC4 golden: the store home in ${variant.name}', (
      tester,
    ) async {
      McTestSession.current.themeVariant = variant;
      await _open(tester);

      expect(find.byKey(sectionPartKey('deals', 'content')), findsOneWidget);
      await _expectGolden('store_home_${variant.name}');
    });
  }

  mcTestWidgets('T-0056-AC1 golden: the lower sections (featured, cart)', (
    tester,
  ) async {
    await _open(tester);
    await scrollStoreUntilVisible(
      tester,
      find.byKey(sectionPartKey('cart', 'content')),
    );

    await _expectGolden('store_home_lower');
  });

  mcTestWidgets('T-0056-AC6 golden: every section loading', (tester) async {
    final backend = McTestSession.current.backend;
    for (final route in [
      'GET /v1/store/banners',
      'GET /v1/store/deals',
      'GET /v1/store/categories',
      'GET /v1/store/featured',
      'GET /v1/me/cart',
    ]) {
      backend.hold(route);
    }
    await _open(tester);

    expect(find.byKey(sectionPartKey('deals', 'skeleton')), findsOneWidget);
    await _expectGolden('store_home_loading');
    for (final route in [
      'GET /v1/store/banners',
      'GET /v1/store/deals',
      'GET /v1/store/categories',
      'GET /v1/store/featured',
      'GET /v1/me/cart',
    ]) {
      await backend.release(route);
    }
    await mcSettle(tester);
  });

  mcTestWidgets('T-0056-AC2 golden: every section failed', (tester) async {
    await _openFailing(tester);

    expect(find.byKey(sectionPartKey('banners', 'error')), findsOneWidget);
    await _expectGolden('store_home_failed');
  });

  mcTestWidgets('T-0056-AC2 golden: an empty store, signed out', (
    tester,
  ) async {
    McTestSession.current.backend
      ..useFixtureSet('commerce.default')
      ..useFixtureSet('identity.default')
      ..backend.useScenario('commerce.empty');
    await ensureStoreContainer();
    await initFlow(tester, () => storeTestHost(storeFlowUnderTest()));
    await mcSettle(tester);

    expect(find.byKey(sectionPartKey('deals', 'empty')), findsOneWidget);
    await _expectGolden('store_home_empty');
  });

  for (final variant in [McThemeVariant.light, McThemeVariant.dark]) {
    mcTestWidgets('T-0056-AC3 golden: the category page in ${variant.name}', (
      tester,
    ) async {
      McTestSession.current.themeVariant = variant;
      await _open(tester, signedIn: false, category: 'heroes');

      expect(find.byKey(categoryGridKey), findsOneWidget);
      await _expectGolden('store_category_${variant.name}');
    });
  }

  mcTestWidgets('T-0056-AC4 golden: the pseudo-locale at 2x', (tester) async {
    McTestSession.current
      ..locale = const Locale('en', 'XA')
      ..textScale = 2;
    await _open(tester);

    expect(tester.takeException(), isNull);
    await _expectGolden('store_home_pseudo_2x');
  });
}

Future<void> _openFailing(WidgetTester tester) async {
  final backend = McTestSession.current.backend
    ..useFixtureSet('commerce.default')
    ..useFixtureSet('identity.default');
  await ensureStoreContainer();
  await signIn(tester, 'reader@mini-client.test');
  backend.backend.useScenario('commerce.server_error');
  await initFlow(tester, () => storeTestHost(storeFlowUnderTest()));
  await mcSettle(tester);
}
