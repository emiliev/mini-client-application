import 'dart:async';

import 'package:comics_details/comics_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockComicsDetailsNavigator extends Mock
    implements ComicsDetailsNavigator {}

final Expando<MockComicsDetailsNavigator> _navigators = Expando(
  'comics_details navigator',
);
final Expando<List<Completer<bool>>> _signIns = Expando(
  'comics_details sign-ins',
);
final Expando<List<DataChanged>> _changes = Expando('comics_details changes');

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub;
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`), so a scenario can
/// look at the page while the feature waits for the app.
MockComicsDetailsNavigator comicsNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

MockComicsDetailsNavigator _newNavigator() {
  final navigator = MockComicsDetailsNavigator();
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

/// Every `DataChanged` published on the bus since the comic opened.
List<DataChanged> announcedChanges() => _changes[McTestSession.current] ??= [];

final Expando<bool> _observed = Expando('comics_details observers');

/// The test root, once per test: the production-shaped container (unless an
/// earlier step such as `I am signed in as` made it), plus a listener on the
/// bus. Called by `I open comic`.
Future<void> ensureComicsContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
  if (_observed[session] ?? false) {
    return;
  }
  _observed[session] = true;
  final changes = announcedChanges();
  final subscription = diContainer<EventBus>().on<DataChanged>().listen(
    changes.add,
  );
  addTearDown(subscription.cancel);
}

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const comicDetailsBodyKey = ValueKey<String>('comics_details.body');
const comicCoverKey = ValueKey<String>('comics_details.cover');
const comicTitleKey = ValueKey<String>('comics_details.title');
const comicFactsKey = ValueKey<String>('comics_details.facts');
const comicCreditsKey = ValueKey<String>('comics_details.creators');
const comicCastKey = ValueKey<String>('comics_details.cast');
const comicCoverPageImageKey = ValueKey<String>('comics_details.cover.image');
const favouriteErrorKey = ValueKey<String>('comics_details.favourite.error');

/// The details page's own scrollable.
Finder comicBodyScrollable() => find.descendant(
  of: find.byKey(comicDetailsBodyKey),
  matching: find.byType(Scrollable),
);

/// Drags the details page until [finder] is on screen.
Future<void> scrollComicUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: comicBodyScrollable().first,
  );
  await mcSettle(tester);
}

/// What the flow state holds, as the tests see it.
typedef FlowStateView = ({ComicId comicId, ComicId? cover});

/// The flow's current state, through `mc_feature_flow`'s public test hook.
/// The state type is package-private (R4; R7 keeps `src/` out of BDD tests),
/// so the hook is asked for `dynamic`. [anchor] is any widget of the flow.
FlowStateView comicsFlowState(WidgetTester tester, Finder anchor) {
  expect(anchor, findsWidgets, reason: 'the comics_details flow is open');
  final dynamic state = flowStateOf<dynamic>(tester.element(anchor.first));
  final dynamic cover = state.cover;
  return (
    comicId: state.comicId as ComicId,
    cover: cover == null ? null : cover.id as ComicId,
  );
}

/// Test-facing facts come from the fixture packages (their CONTRACT.md
/// files), never from feature code: the comics and characters of seed 42,
/// the harness's seed.
final ComicUniverse comicUniverse = ComicUniverse(42);
final List<CharacterRecord> _cast = CharacterUniverse(
  42,
  defaultMockClock,
).byName;

ComicRecord comicRecord(int id) =>
    comicUniverse.findComic(id) ?? (throw ArgumentError.value(id, 'comic'));

CharacterRecord characterNamed(String name) =>
    _cast.firstWhere((c) => c.name == name);

CharacterRecord characterWithId(int id) => _cast.firstWhere((c) => c.id == id);

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// The English role labels (the en ARB's copy, as a user reads it).
const Map<String, String> englishRoles = {
  'writer': 'Writer',
  'penciller': 'Penciller',
  'inker': 'Inker',
  'colorist': 'Colorist',
  'letterer': 'Letterer',
  'cover_artist': 'Cover artist',
};

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget comicsTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget comicsDetailsFlowUnderTest(int id) =>
    ComicsDetailsFlow(navigator: comicsNavigator(), comicId: ComicId(id));

/// The art [image] is drawn from: the bundled asset of its fixture path.
AssetImage bundledArtFor(ApiImage image) {
  final resolved = const BundledImageResolver().resolve(image);
  return switch (resolved) {
    AssetResolvedImage(:final key, :final package) => AssetImage(
      key,
      package: package,
    ),
    NetworkResolvedImage() => throw StateError('not bundled: $image'),
  };
}

/// Text with its non-breaking and narrow spaces as plain ones: intl puts
/// them between a German amount and its currency sign.
String plainSpaces(String text) => text.replaceAll(RegExp('[  ]'), ' ');

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  comicsFixtureSets.forEach(McFixtureSets.register);
  charactersFixtureSets.forEach(McFixtureSets.register);
  identityFixtureSets.forEach(McFixtureSets.register);
}
