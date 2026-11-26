import 'package:characters_list/characters_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockCharactersListNavigator extends Mock
    implements CharactersListNavigator {}

final Expando<MockCharactersListNavigator> _navigators = Expando(
  'characters_list navigator',
);
final Expando<double> _scrollOffsets = Expando('characters_list scroll');

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub.
MockCharactersListNavigator charactersNavigator() =>
    _navigators[McTestSession.current] ??= MockCharactersListNavigator();

/// Where a step left the grid's scroll position, for a later step to compare.
double? rememberedScrollOffset() => _scrollOffsets[McTestSession.current];

void rememberScrollOffset(double pixels) =>
    _scrollOffsets[McTestSession.current] = pixels;

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const charactersGridKey = ValueKey<String>('characters_list.grid');
const characterPreviewTitleKey = ValueKey<String>(
  'characters_list.preview.title',
);
const relatedComicsKey = ValueKey<String>('characters_list.preview.comics');

/// What the flow state selects, as the tests see it.
typedef FlowStateView = ({
  String? teamId,
  ({CharacterId id, String name})? preview,
});

/// The flow's current state, through `mc_feature_flow`'s public test hook:
/// the controller's state is authoritative (flow_builder only sees structural
/// changes, F-0018). The state type is package-private (R4; R7 keeps `src/`
/// out of BDD tests), so the hook is asked for `dynamic`.
FlowStateView charactersFlowState(WidgetTester tester) {
  // Anchored to the flow's own grid, not to whichever Scaffold comes first.
  final grid = find.byKey(charactersGridKey, skipOffstage: false);
  expect(grid, findsOneWidget, reason: 'the characters_list flow is open');
  final dynamic state = flowStateOf<dynamic>(tester.element(grid));
  final dynamic preview = state.preview;
  return (
    teamId: state.teamId as String?,
    preview: preview == null
        ? null
        : (id: preview.id as CharacterId, name: preview.name as String),
  );
}

/// The grid's own scrollable.
Finder charactersScrollable() => find.descendant(
  of: find.byKey(charactersGridKey),
  matching: find.byType(Scrollable),
);

ScrollPosition charactersScrollPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(charactersScrollable()).position;

/// How many characters the grid holds (built or not): its child count.
int charactersShown(WidgetTester tester) {
  final grid = tester.widget<SliverGrid>(
    find.descendant(
      of: find.byKey(charactersGridKey),
      matching: find.byType(SliverGrid),
    ),
  );
  return (grid.delegate as SliverChildBuilderDelegate).childCount!;
}

/// Test-facing facts come from the fixture package (CONTRACT.md), never from
/// feature code: the casts of `characters.default` (seed 42, the harness's)
/// and `characters.paged_45`, in name order.
final List<CharacterRecord> defaultCast = CharacterUniverse(
  42,
  defaultMockClock,
).byName;
final List<CharacterRecord> _paged45 = CharacterUniverse.synthetic(
  45,
  defaultMockClock,
).byName;

CharacterRecord characterNamed(String name) => [
  ...defaultCast,
  ..._paged45,
].firstWhere((c) => c.name == name);

/// The comics of `comics.default` (seed 42), for the preview's related
/// comics (T-0041).
final ComicUniverse comicUniverse = ComicUniverse(42);

/// What the preview lists for [name]: the first 5 comics in title order.
List<ComicRecord> relatedComicsOf(String name) =>
    comicUniverse.comicsOfCharacter(characterNamed(name).id).take(5).toList();

/// The comic of `comics.default` titled [title].
ComicRecord comicTitled(String title) =>
    comicUniverse.byTitle.firstWhere((c) => c.title == title);

/// The preview page's own scrollable.
Finder previewScrollable() => find.ancestor(
  of: find.byKey(relatedComicsKey),
  matching: find.byType(Scrollable),
);

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production, T-0033).
Widget charactersTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget charactersListFlowUnderTest() =>
    CharactersListFlow(navigator: charactersNavigator());

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
  charactersFixtureSets.forEach(McFixtureSets.register);
  comicsFixtureSets.forEach(McFixtureSets.register);
}
