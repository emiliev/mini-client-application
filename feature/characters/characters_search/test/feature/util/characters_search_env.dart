import 'package:characters_search/characters_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_feedback/mc_ds_feedback.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockCharactersSearchNavigator extends Mock
    implements CharactersSearchNavigator {}

final Expando<MockCharactersSearchNavigator> _navigators = Expando(
  'characters_search navigator',
);

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub.
MockCharactersSearchNavigator searchNavigator() =>
    _navigators[McTestSession.current] ??= MockCharactersSearchNavigator();

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const searchFieldKey = ValueKey<String>('characters_search.field');
const searchResultsKey = ValueKey<String>('characters_search.results');
const searchSortKey = ValueKey<String>('characters_search.facets.sort');
const searchTeamKey = ValueKey<String>('characters_search.facets.team');
const searchHistoryKey = ValueKey<String>('characters_search.history');
const String searchResultKeyPrefix = 'characters_search.result.';

/// Test-facing facts come from the fixture package (its CONTRACT.md), never
/// from feature code: the cast of `characters.default` (seed 42, the
/// harness's), in name order.
final List<CharacterRecord> defaultCast = CharacterUniverse(
  42,
  defaultMockClock,
).byName;

/// How many characters one request asks for (`limit`).
const int searchPageSize = 30;

/// The characters whose name starts with [prefix] (any case), narrowed to
/// [team] when given, in the order of the `orderBy` value [order]: what the
/// backend answers, worked out here from the fixture's cast. Ties end on the
/// id, as the contract says.
List<CharacterRecord> matchesOf(
  String prefix, {
  String order = 'name',
  String? team,
}) {
  final lower = prefix.trim().toLowerCase();
  final matches = [
    for (final c in defaultCast)
      if (c.name.toLowerCase().startsWith(lower) &&
          (team == null || c.team == team))
        c,
  ];
  int byId(CharacterRecord a, CharacterRecord b) => a.id.compareTo(b.id);
  matches.sort(switch (order) {
    'name' => (a, b) => a.name.compareTo(b.name),
    '-name' => (a, b) => b.name.compareTo(a.name),
    'modified' => (a, b) {
      final c = a.modified.compareTo(b.modified);
      return c != 0 ? c : byId(a, b);
    },
    '-modified' => (a, b) {
      final c = b.modified.compareTo(a.modified);
      return c != 0 ? c : byId(a, b);
    },
    _ => throw ArgumentError.value(order, 'order'),
  });
  return matches;
}

/// The character named [name].
CharacterRecord characterNamed(String name) =>
    defaultCast.firstWhere((c) => c.name == name);

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget searchTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The flow as the app builds it, over the session's navigator mock.
Widget searchFlowUnderTest({String? initialQuery}) => CharactersSearchFlow(
  navigator: searchNavigator(),
  initialQuery: initialQuery,
);

/// Lets real file I/O (the recent searches on `mc_storage`) complete, then
/// settles: a `testWidgets` body runs on fake time, and a real read or write
/// finishes only once real time passes (F-0038 fact 1). Settles with
/// `mcSettle`, so a hold set earlier keeps its spinner.
Future<void> letStorageFinish(WidgetTester tester) async {
  await mcFinishStorageIo(tester);
  await mcSettle(tester);
}

/// Opens a new search flow (a new flow instance: the previous one, if any,
/// is unmounted first) and lets it read the recent searches.
Future<void> openSearch(
  WidgetTester tester, {
  String? initialQuery,
  bool wait = true,
}) async {
  if (McTestSession.current.containerInitialized) {
    await tester.pumpWidget(const SizedBox.shrink());
  }
  await initFlow(
    tester,
    () => searchTestHost(searchFlowUnderTest(initialQuery: initialQuery)),
  );
  if (wait) {
    await letStorageFinish(tester);
  } else {
    // No fake time passes (zero-delay timers, as Dio's, still run) and no
    // real I/O completes: the history read is still on its way, and
    // whatever the flow sent at once has been sent.
    await tester.pump(Duration.zero);
  }
}

/// The one search field.
Finder searchField() => find.descendant(
  of: find.byKey(searchFieldKey),
  matching: find.byType(EditableText),
);

/// The results list's scrollable.
Finder resultsScrollable() => find
    .descendant(
      of: find.byKey(searchResultsKey),
      matching: find.byType(Scrollable),
    )
    .first;

ScrollPosition resultsPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(resultsScrollable()).position;

/// A page is on its way (the list's footer spinner).
bool morePagesLoading() => find
    .descendant(
      of: find.byKey(searchResultsKey),
      matching: find.byType(McLoading),
    )
    .evaluate()
    .isNotEmpty;

/// One result row as the screen shows it.
typedef ShownResult = ({int id, String name, ImageProvider? art});

final RegExp _resultKey = RegExp(r'^characters_search\.result\.(\d+)$');

/// The result rows, top to bottom: scrolls the list from its start and reads
/// each row once (rows below the fold are built only when they come near the
/// screen). With [atLeast], stops once that many were seen; without, scrolls
/// to the very end, which loads every page.
Future<List<ShownResult>> shownResults(
  WidgetTester tester, {
  int? atLeast,
}) async {
  expect(find.byKey(searchResultsKey), findsOneWidget, reason: 'results show');
  resultsPosition(tester).jumpTo(0);
  await tester.pump();
  final seen = <int, ({double dy, ShownResult row})>{};
  while (true) {
    final position = resultsPosition(tester);
    for (final element
        in find
            .descendant(
              of: find.byKey(searchResultsKey),
              matching: find.byWidgetPredicate(
                (w) => w is ListTile && w.key is ValueKey<String>,
              ),
            )
            .evaluate()) {
      final tile = element.widget as ListTile;
      final key = (tile.key! as ValueKey<String>).value;
      final match = _resultKey.firstMatch(key);
      if (match == null) {
        continue;
      }
      final id = int.parse(match.group(1)!);
      if (seen.containsKey(id)) {
        continue;
      }
      final box = element.renderObject! as RenderBox;
      final dy = box.localToGlobal(Offset.zero).dy + position.pixels;
      final images = find
          .descendant(of: find.byKey(tile.key!), matching: find.byType(Image))
          .evaluate()
          .map((e) => (e.widget as Image).image)
          .toList();
      seen[id] = (
        dy: dy,
        row: (
          id: id,
          name: (tile.title! as Text).data!,
          art: images.isEmpty ? null : images.single,
        ),
      );
    }
    if (atLeast != null && seen.length >= atLeast) {
      break;
    }
    if (position.pixels >= position.maxScrollExtent) {
      // At the end: a page may be loading, and may lengthen the list.
      final before = position.maxScrollExtent;
      await mcSettle(tester);
      if (resultsPosition(tester).maxScrollExtent <= before &&
          !morePagesLoading()) {
        break;
      }
      continue;
    }
    position.jumpTo(
      (position.pixels + 300).clamp(0, position.maxScrollExtent),
    );
    await tester.pump();
  }
  resultsPosition(tester).jumpTo(0);
  // A page the scrolling asked for lands before the step ends.
  await mcSettle(tester);
  final rows = seen.values.toList()..sort((a, b) => a.dy.compareTo(b.dy));
  return [for (final r in rows) r.row];
}

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

/// The list shows the first [count] matches of [prefix] (for [team], in
/// [order]), top to bottom, each with its name and its bundled art, and
/// nothing else before them. With [count] equal to the number of matches the
/// list is read to its very end.
Future<void> expectResults(
  WidgetTester tester, {
  required String prefix,
  required int count,
  String order = 'name',
  String? team,
}) async {
  final expected = matchesOf(prefix, order: order, team: team);
  expect(
    expected.length,
    greaterThanOrEqualTo(count),
    reason: 'the fixture has $count matches for "$prefix"',
  );
  final all = count == expected.length;
  final shown = await shownResults(tester, atLeast: all ? null : count);
  expect(
    [for (final row in shown.take(count)) row.id],
    [for (final c in expected.take(count)) c.id],
    reason: 'the rows, top to bottom, are the matches in $order order',
  );
  if (all) {
    expect(shown, hasLength(count), reason: 'no row beyond the matches');
  }
  for (final (i, row) in shown.take(count).indexed) {
    final record = expected[i];
    expect(row.name, record.name, reason: 'row ${i + 1} name');
    expect(
      row.art,
      bundledArtFor(record.thumbnail),
      reason: '${record.name} draws its bundled art',
    );
  }
}

/// Taps the result row named [name] [times] times, [between] of fake time
/// apart (zero: within one frame), then settles.
Future<void> tapResult(
  WidgetTester tester,
  String name, {
  int times = 1,
  Duration between = Duration.zero,
}) async {
  final row = find.descendant(
    of: find.byKey(searchResultsKey),
    matching: find.text(name),
  );
  await tester.scrollUntilVisible(row, 200, scrollable: resultsScrollable());
  await mcSettle(tester);
  expect(row.hitTestable(), findsOneWidget, reason: 'one "$name" row');
  for (var i = 0; i < times; i++) {
    if (i > 0 && between > Duration.zero) {
      await tester.pump(between);
    }
    await tester.tap(row.hitTestable());
  }
  await mcSettle(tester);
}

/// Taps the chip labelled [label] in the group [group], scrolling its row
/// until the chip is on screen.
Future<void> tapChip(WidgetTester tester, Key group, String label) async {
  final chip = find.descendant(
    of: find.byKey(group),
    matching: find.byWidgetPredicate((w) => w is McChip && w.label == label),
  );
  expect(chip, findsOneWidget, reason: 'one "$label" chip');
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip.hitTestable());
  await mcSettle(tester);
}

/// Whether the chip labelled [label] of [group] is selected.
bool chipSelected(WidgetTester tester, Key group, String label) {
  final chip = find.descendant(
    of: find.byKey(group),
    matching: find.byWidgetPredicate((w) => w is McChip && w.label == label),
  );
  expect(chip, findsOneWidget, reason: 'one "$label" chip');
  return tester.widget<McChip>(chip).selected;
}

/// The labels of the chips of [group] that are selected.
List<String> selectedChips(WidgetTester tester, Key group) => [
  for (final chip in tester.widgetList<McChip>(
    find.descendant(of: find.byKey(group), matching: find.byType(McChip)),
  ))
    if (chip.selected) chip.label,
];

/// The recent searches on screen, top to bottom.
List<String> shownHistory(WidgetTester tester) {
  expect(
    find.byKey(searchHistoryKey),
    findsOneWidget,
    reason: 'the recent searches show',
  );
  return [
    for (final tile in tester.widgetList<ListTile>(
      find.descendant(
        of: find.byKey(searchHistoryKey),
        matching: find.byType(ListTile),
      ),
    ))
      (tile.title! as Text).data!,
  ];
}

/// Splits a step's comma-separated list (`'spi, amber'`).
List<String> listArgument(String text) => [
  for (final part in text.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  charactersFixtureSets.forEach(McFixtureSets.register);
}
