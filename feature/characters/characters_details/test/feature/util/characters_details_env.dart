import 'dart:async';

import 'package:characters_details/characters_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockCharacterDetailsNavigator extends Mock
    implements CharacterDetailsNavigator {}

final Expando<MockCharacterDetailsNavigator> _navigators = Expando(
  'characters_details navigator',
);
final Expando<List<Completer<bool>>> _signIns = Expando(
  'characters_details sign-ins',
);
final Expando<List<DataChanged>> _changes = Expando(
  'characters_details changes',
);

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub;
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`), so a scenario can
/// look at the page while the feature waits for the app.
MockCharacterDetailsNavigator charactersNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

MockCharacterDetailsNavigator _newNavigator() {
  final navigator = MockCharacterDetailsNavigator();
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

/// Every `DataChanged` published on the bus since the character opened.
List<DataChanged> announcedChanges() => _changes[McTestSession.current] ??= [];

final Expando<bool> _observed = Expando('characters_details observers');

/// The test root, once per test: the production-shaped container (unless an
/// earlier step such as `I am signed in as` made it), plus a listener on the
/// bus. Called by `I open character`.
Future<void> ensureCharactersContainer() async {
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
const characterDetailsBodyKey = ValueKey<String>('characters_details.body');
const characterPortraitKey = ValueKey<String>('characters_details.portrait');
const characterNameKey = ValueKey<String>('characters_details.name');
const characterAliasesKey = ValueKey<String>('characters_details.aliases');
const characterBioKey = ValueKey<String>('characters_details.bio');
const characterStatsKey = ValueKey<String>('characters_details.stats');
const characterComicsKey = ValueKey<String>('characters_details.comics');
const characterComicsEmptyKey = ValueKey<String>(
  'characters_details.comics.empty',
);
const characterFactsKey = ValueKey<String>('characters_details.facts');
const favouriteErrorKey = ValueKey<String>(
  'characters_details.favourite.error',
);

/// The key of page [n] in `I open character {id} on two pages` (a test host
/// key, not a feature key).
ValueKey<String> characterPageKey(int n) =>
    ValueKey<String>('test.character.page.$n');

/// The details page's own scrollable.
Finder characterBodyScrollable() => find.descendant(
  of: find.byKey(characterDetailsBodyKey),
  matching: find.byType(Scrollable),
);

/// Drags the profile page until [finder] is on screen.
Future<void> scrollCharacterUntilVisible(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: characterBodyScrollable().first,
  );
  await mcSettle(tester);
}

/// Scrolls [target] into view, then taps it [times] times, [between] of fake
/// time apart (zero: within one frame), then settles.
Future<void> tapCharacterTarget(
  WidgetTester tester,
  Finder target, {
  int times = 1,
  Duration between = Duration.zero,
}) async {
  await scrollCharacterUntilVisible(tester, target);
  expect(target.hitTestable(), findsOneWidget, reason: 'one tappable target');
  for (var i = 0; i < times; i++) {
    if (i > 0 && between > Duration.zero) {
      await tester.pump(between);
    }
    await tester.tap(target.hitTestable());
  }
  await mcSettle(tester);
}

/// The card of the comic titled [title] in the comics row.
Finder comicCard(String title) => find.descendant(
  of: find.byKey(characterComicsKey),
  matching: find.text(title),
);

/// Test-facing facts come from the fixture packages (their CONTRACT.md
/// files), never from feature code: the comics and characters of seed 42,
/// the harness's seed.
final ComicUniverse comicUniverse = ComicUniverse(42);
final CharacterUniverse characterUniverse = CharacterUniverse(
  42,
  defaultMockClock,
);

CharacterRecord characterWithId(int id) =>
    characterUniverse.find(id) ?? (throw ArgumentError.value(id, 'character'));

/// The comics that feature [characterId], in the order the page shows them
/// (the comics domain's title order).
List<ComicRecord> comicsOf(int characterId) =>
    comicUniverse.comicsOfCharacter(characterId);

/// The fixture comic titled [title] (titles are unique: series title plus
/// issue).
ComicRecord comicTitled(String title) => comicUniverse.byTitle.firstWhere(
  (c) => c.title == title,
  orElse: () => throw ArgumentError.value(title, 'comic title'),
);

/// The fixture user with [email].
FixtureUser fixtureUser(String email) =>
    fixtureUsers.firstWhere((u) => u.email == email);

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget charactersTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget characterDetailsFlowUnderTest(int id) => CharacterDetailsFlow(
  navigator: charactersNavigator(),
  characterId: CharacterId(id),
);

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

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  comicsFixtureSets.forEach(McFixtureSets.register);
  charactersFixtureSets.forEach(McFixtureSets.register);
  identityFixtureSets.forEach(McFixtureSets.register);
}
