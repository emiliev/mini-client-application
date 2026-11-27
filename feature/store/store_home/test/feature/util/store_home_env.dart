import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_auth/mc_api_auth.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_ds_navigation/mc_ds_navigation.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_fixtures_commerce/mc_fixtures_commerce.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:store_home/store_home.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockStoreHomeNavigator extends Mock implements StoreHomeNavigator {}

final Expando<MockStoreHomeNavigator> _navigators = Expando(
  'store_home navigator',
);
final Expando<List<Completer<bool>>> _signIns = Expando('store_home sign-ins');

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub;
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`), so a scenario can
/// look at the page while the feature waits for the app.
MockStoreHomeNavigator storeNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

/// Every hand-over the feature asked the app for, in order
/// (`comic 501501`, `search amber`, `cart`): counted in all, unlike
/// mocktail's verify, which forgets what it already verified.
List<String> navigatorCalls() => _calls[McTestSession.current] ??= [];
final Expando<List<String>> _calls = Expando('store_home navigator calls');

MockStoreHomeNavigator _newNavigator() {
  final navigator = MockStoreHomeNavigator();
  when(() => navigator.openComic(any())).thenAnswer(
    (i) => navigatorCalls().add(
      'comic ${(i.positionalArguments.single as ComicId).value}',
    ),
  );
  when(() => navigator.openSearch(any())).thenAnswer(
    (i) => navigatorCalls().add('search ${i.positionalArguments.single}'),
  );
  when(navigator.openCart).thenAnswer((_) => navigatorCalls().add('cart'));
  when(navigator.requestSignIn).thenAnswer((_) {
    final answer = Completer<bool>();
    pendingSignIns().add(answer);
    return answer.future;
  });
  return navigator;
}

/// The sign-ins the feature asked for and nobody answered yet, oldest first.
List<Completer<bool>> pendingSignIns() =>
    _signIns[McTestSession.current] ??= [];

/// The test root, once per test (unless an earlier step such as `I am
/// signed in as` made it).
Future<void> ensureStoreContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
}

/// The time the deals count down against: the fixtures' fixed clock, the
/// instant the commerce fixtures' `endsAt` values are counted from.
DateTime storeClock() => defaultMockClock;

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget storeTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget storeFlowUnderTest({String? category}) => StoreHomeFlow(
  navigator: storeNavigator(),
  clock: storeClock,
  initialCategory: category == null ? null : CategoryId(category),
);

// --- keys (plan 05 §3.5: steps find by key, never by a feature widget type)

const storeHomeBodyKey = ValueKey<String>('store_home.body');
const categoryGridKey = ValueKey<String>('store_category.grid');
const categoryTitleKey = ValueKey<String>('store_category.title');

/// The sections, by the name a scenario uses, in page order.
const List<String> storeSections = [
  'banners',
  'deals',
  'categories',
  'featured',
  'cart',
];

ValueKey<String> sectionKey(String section) {
  expect(storeSections, contains(section), reason: 'a store section');
  return ValueKey('store_home.$section');
}

ValueKey<String> sectionPartKey(String section, String part) =>
    ValueKey('${sectionKey(section).value}.$part');

ValueKey<String> dealKey(int id) => ValueKey('store_home.deal.$id');
ValueKey<String> featuredKey(int id) => ValueKey('store_home.featured.$id');
ValueKey<String> bannerKey(String id) => ValueKey('store_home.banner.$id');
ValueKey<String> categoryKey(String id) => ValueKey('store_home.category.$id');
ValueKey<String> productKey(int id) => ValueKey('store_category.product.$id');

/// The store home's own vertical scrollable.
Finder storeBodyScrollable() => find
    .descendant(
      of: find.byKey(storeHomeBodyKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// Lets answers that are on their way land: zero-delay timers (Dio) and a
/// few frames, without settling (a refresh control or a hold may keep the
/// screen busy).
Future<void> letSectionsLand(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Back to the top of the store home.
Future<void> scrollStoreToTop(WidgetTester tester) async {
  tester.state<ScrollableState>(storeBodyScrollable()).position.jumpTo(0);
  await tester.pump();
}

/// Scrolls the store home from the top until [finder] is built and on
/// screen (a lazy list builds only what is near the screen, F-0040 fact 6).
Future<void> scrollStoreUntilVisible(WidgetTester tester, Finder finder) async {
  await scrollStoreToTop(tester);
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: storeBodyScrollable(),
  );
  await tester.pump();
}

/// The section headers' titles from the top of the store home to its end,
/// in the order they appear (collected while scrolling down).
Future<List<String>> sectionTitlesInOrder(WidgetTester tester) async {
  await scrollStoreToTop(tester);
  final titles = <String>[];
  final position = tester
      .state<ScrollableState>(storeBodyScrollable())
      .position;
  for (var step = 0; step < 50; step++) {
    final shown = [
      for (final element in find.byType(McSectionHeader).evaluate())
        (
          title: (element.widget as McSectionHeader).title,
          y: tester.getTopLeft(find.byWidget(element.widget)).dy,
        ),
    ]..sort((a, b) => a.y.compareTo(b.y));
    for (final header in shown) {
      if (!titles.contains(header.title)) {
        titles.add(header.title);
      }
    }
    if (position.pixels >= position.maxScrollExtent) {
      break;
    }
    position.jumpTo(
      (position.pixels + 300).clamp(0, position.maxScrollExtent),
    );
    await tester.pump();
  }
  await scrollStoreToTop(tester);
  return titles;
}

/// Scrolls the store home to [section] (its header and the start of its
/// content on screen).
Future<void> scrollToSection(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  await scrollStoreUntilVisible(tester, find.byKey(sectionKey(section)));
  await tester.ensureVisible(find.byKey(sectionKey(section)));
  await tester.pump();
}

/// The horizontal scrollable of [section]'s carousel.
Finder carouselScrollable(String section) => find
    .descendant(
      of: find.byKey(sectionPartKey(section, 'content')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls [section]'s carousel forward until [item] is built, then brings
/// it fully into view. Forward only: checking items one after the other
/// this way also proves their order.
Future<void> scrollCarouselTo(
  WidgetTester tester,
  String section,
  Finder item,
) async {
  await scrollToSection(tester, section);
  await tester.scrollUntilVisible(
    item,
    120,
    scrollable: carouselScrollable(section),
  );
  await tester.ensureVisible(item);
  await tester.pump();
}

/// Scrolls the home to [section] and taps [target] inside it, [times]
/// times, [between] of fake time apart (zero: within one frame). An item of
/// a carousel is scrolled into view sideways.
Future<void> tapIn(
  WidgetTester tester,
  String section,
  Finder target, {
  int times = 1,
  Duration between = Duration.zero,
}) async {
  final scoped = find.descendant(
    of: find.byKey(sectionKey(section)),
    matching: target,
  );
  await scrollToSection(tester, section);
  final carousel = find.byKey(sectionPartKey(section, 'content'));
  final isCarousel =
      carousel.evaluate().isNotEmpty &&
      find
          .descendant(of: carousel, matching: find.byType(Scrollable))
          .evaluate()
          .isNotEmpty;
  if (isCarousel && scoped.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      scoped,
      120,
      scrollable: carouselScrollable(section),
    );
  }
  if (scoped.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      scoped,
      200,
      scrollable: storeBodyScrollable(),
    );
  }
  await tester.ensureVisible(scoped.first);
  await tester.pump();
  expect(scoped.hitTestable(), findsWidgets, reason: 'a tappable target');
  for (var i = 0; i < times; i++) {
    if (i > 0 && between > Duration.zero) {
      await tester.pump(between);
    }
    await tester.tap(scoped.hitTestable().first);
  }
  await mcSettle(tester);
}

/// What the flow state holds, as the tests see it.
typedef FlowStateView = ({String? category, String? name, String? root});

/// The flow's current state, through `mc_feature_flow`'s public test hook
/// (the state type is package-private, R4/R7).
FlowStateView storeFlowState(WidgetTester tester) {
  final anchor = find.byType(Scaffold);
  expect(anchor, findsWidgets, reason: 'the store_home flow is open');
  final dynamic state = flowStateOf<dynamic>(tester.element(anchor.first));
  final dynamic category = state.category;
  final dynamic root = state.rootCategory;
  return (
    category: category == null ? null : category.id as String,
    name: category == null ? null : category.name as String?,
    root: root == null ? null : root.id as String,
  );
}

// --- fixture facts (mc_fixtures_commerce CONTRACT.md, seed 42) ------------

/// The store of the harness's seed, as the fixtures build it: test-facing
/// facts come from the fixture package, never from feature code.
final Catalogue storeCatalogue = catalogueFor(42, empty: false);

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// Integer cents as an English euro price, computed here (an oracle that
/// does not use the app's formatter): `1299` is `€12.99`.
String euros(int cents) =>
    '€${_group(cents ~/ 100, ',')}.${(cents % 100).toString().padLeft(2, '0')}';

/// The same in German: `12,99 €` (with intl's no-break space).
String eurosDe(int cents) =>
    '${_group(cents ~/ 100, '.')},${(cents % 100).toString().padLeft(2, '0')}'
    ' €';

String _group(int units, String separator) {
  final digits = '$units';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(separator);
    }
    out.write(digits[i]);
  }
  return out.toString();
}

/// Text with its non-breaking and narrow spaces as plain ones.
String plainSpaces(String text) =>
    text.replaceAll(RegExp('[\u00a0\u202f]'), ' ');

/// Puts [quantity] of product [productId] in [email]'s cart, straight on the
/// backend engine (a minted token, no request through the app's `Dio`), so
/// the harness records nothing.
Future<void> putInCart(
  WidgetTester tester,
  String email,
  int productId,
  int quantity,
) async {
  final user = fixtureUser(email);
  final dio = McTestSession.current.backend.backend.createDio();
  final response = await tester.runAsync(
    () => dio.put<Object?>(
      'v1/me/cart/items/$productId',
      data: {'quantity': quantity},
      options: Options(
        headers: {'Authorization': 'Bearer ${mintAccessToken(user.id, 1)}'},
      ),
    ),
  );
  expect(response?.statusCode, 200, reason: 'the cart line was set');
}

/// Signs [email] in through the real `AuthApi` of the test container
/// (inside `runAsync`: the session saves to a real file, F-0038).
Future<void> signIn(WidgetTester tester, String email) async {
  final user = fixtureUser(email);
  final result = await tester.runAsync(
    () => diContainer<AuthApi>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
}

/// The shared Retry label in the running test's locale (`mc_l10n_core`).
String retryLabel(WidgetTester tester) =>
    McL10nCoreL10n.of(tester.element(find.byType(Scaffold).first)).commonRetry;

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  // `any()` for the navigator's argument type (an int at run time).
  registerFallbackValue(const ComicId(0));
  commerceFixtureSets.forEach(McFixtureSets.register);
  identityFixtureSets.forEach(McFixtureSets.register);
}
