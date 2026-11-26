import 'package:discovery_search/discovery_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_ds_inputs/mc_ds_inputs.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_media/mc_media.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockDiscoverySearchNavigator extends Mock
    implements DiscoverySearchNavigator {}

final Expando<MockDiscoverySearchNavigator> _navigators = Expando(
  'discovery_search navigator',
);

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub.
MockDiscoverySearchNavigator searchNavigator() =>
    _navigators[McTestSession.current] ??= MockDiscoverySearchNavigator();

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const searchFieldKey = ValueKey<String>('discovery_search.field');
const searchResultsKey = ValueKey<String>('discovery_search.results');
const searchFiltersKey = ValueKey<String>('discovery_search.filters');
const searchHistoryKey = ValueKey<String>('discovery_search.history');
const searchNoHistoryKey = ValueKey<String>('discovery_search.history.none');
const String searchResultKeyPrefix = 'discovery_search.result.';

/// The key of a section header (`character` or `comic`).
ValueKey<String> searchSectionKey(String type) =>
    ValueKey<String>('discovery_search.section.$type');

/// The key of a result row: `discovery_search.result.<type>.<id>`.
ValueKey<String> searchResultKey(String type, int id) =>
    ValueKey<String>('$searchResultKeyPrefix$type.$id');

/// The wire name of a section the scenarios name in English.
String searchTypeNamed(String section) => switch (section) {
  'characters' || 'character' => 'character',
  'comics' || 'comic' => 'comic',
  _ => throw ArgumentError.value(section, 'section'),
};

/// Test-facing facts come from the fixture packages (their CONTRACT.md
/// files), never from feature code: the search index of seed 42, the
/// harness's seed, ranked by `mc_fixtures_discovery` itself.
final SearchIndex searchIndex = SearchIndex.fromUniverses(42, defaultMockClock);

/// The ranked matches of [type] for [query], as the backend serves them.
List<SearchEntry> rankedMatches(String query, String type) => [
  for (final match in searchIndex.search(query, types: [type])) match.entry,
];

/// The entry of [type] titled [title] (titles are unique within a type).
SearchEntry entryTitled(String type, String title) =>
    searchIndex.search(title, types: [type]).first.entry;

/// The page size the feature asks for (`limit`), as the contract allows.
const int searchPageSize = 20;

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
Widget searchFlowUnderTest({String? initialQuery}) => DiscoverySearchFlow(
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

/// The header of the [type] section has the action [label], drawn whole: a
/// label ellipsised by the header's width would read as something else.
Future<void> expectSectionAction(
  WidgetTester tester,
  String type,
  String label,
) async {
  final text = find.descendant(
    of: find.byKey(searchSectionKey(type)),
    matching: find.text(label),
  );
  expect(text, findsOneWidget, reason: 'the $type section offers "$label"');
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: '"$label" is shown whole, not ellipsised',
  );
}

/// Whether the search field has the keyboard focus.
bool searchFieldFocused(WidgetTester tester) =>
    tester.widget<EditableText>(searchField()).focusNode.hasFocus;

/// Taps the result row titled [title] ([times] taps within one frame).
Future<void> tapResult(
  WidgetTester tester,
  String title, {
  int times = 1,
}) async {
  final row = find.descendant(
    of: find.byKey(searchResultsKey),
    matching: find.text(title),
  );
  await tester.scrollUntilVisible(row, 200, scrollable: resultsScrollable());
  await mcSettle(tester);
  expect(row.hitTestable(), findsOneWidget, reason: 'one "$title" row');
  for (var i = 0; i < times; i++) {
    await tester.tap(row.hitTestable());
  }
  await mcSettle(tester);
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

/// One result row as the screen shows it.
typedef ShownResult = ({
  String type,
  int id,
  String title,
  String? subtitle,
  ImageProvider? art,
});

final RegExp _resultKey = RegExp(r'^discovery_search\.result\.(\w+)\.(\d+)$');

/// Every result row of the list, top to bottom: scrolls the list from its
/// start to its end and reads each row once (rows below the fold are built
/// only when they come near the screen).
Future<List<ShownResult>> shownResults(WidgetTester tester) async {
  expect(find.byKey(searchResultsKey), findsOneWidget, reason: 'results show');
  final position = tester.state<ScrollableState>(resultsScrollable()).position;
  position.jumpTo(0);
  await tester.pump();
  final seen = <String, ({double dy, ShownResult row})>{};
  while (true) {
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
      if (match == null || seen.containsKey(key)) {
        continue;
      }
      final box = element.renderObject! as RenderBox;
      final dy = box.localToGlobal(Offset.zero).dy + position.pixels;
      final images = find
          .descendant(of: find.byKey(tile.key!), matching: find.byType(Image))
          .evaluate()
          .map((e) => (e.widget as Image).image)
          .toList();
      seen[key] = (
        dy: dy,
        row: (
          type: match.group(1)!,
          id: int.parse(match.group(2)!),
          title: (tile.title! as Text).data!,
          subtitle: (tile.subtitle as Text?)?.data,
          art: images.isEmpty ? null : images.single,
        ),
      );
    }
    if (position.pixels >= position.maxScrollExtent) {
      break;
    }
    position.jumpTo(
      (position.pixels + 300).clamp(0, position.maxScrollExtent),
    );
    await tester.pump();
  }
  position.jumpTo(0);
  await tester.pump();
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

/// Whether the type chip labelled [label] is selected.
bool chipSelected(WidgetTester tester, String label) {
  final chip = find.descendant(
    of: find.byKey(searchFiltersKey),
    matching: find.byWidgetPredicate((w) => w is McChip && w.label == label),
  );
  expect(chip, findsOneWidget, reason: 'one "$label" chip');
  return tester.widget<McChip>(chip).selected;
}

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

/// The section of [type] lists the first [count] ranked matches of [query]
/// for that type, in the backend's order, each with its title, its subtitle
/// and its bundled art; and no other result of that type shows.
Future<void> expectSectionShows(
  WidgetTester tester, {
  required String type,
  required int count,
  required String query,
}) async {
  final expected = rankedMatches(query, type).take(count).toList();
  expect(expected, hasLength(count), reason: 'the fixture has $count');
  final shown = [
    for (final row in await shownResults(tester))
      if (row.type == type) row,
  ];
  expect(
    find.byKey(searchSectionKey(type)),
    findsOneWidget,
    reason: 'the $type section shows',
  );
  expect(
    [for (final row in shown) row.id],
    [for (final entry in expected) entry.id],
    reason: 'the $type rows, top to bottom, are the ranked matches',
  );
  for (final (i, row) in shown.indexed) {
    final entry = expected[i];
    expect(row.title, entry.title, reason: 'row ${i + 1} title');
    expect(row.subtitle, entry.subtitle, reason: 'row ${i + 1} subtitle');
    expect(row.art, bundledArtFor(entry.thumbnail), reason: 'row ${i + 1} art');
  }
}

/// The section headers on screen (scrolled to the top), top to bottom, by
/// type (`character`, `comic`).
List<String> shownSections(WidgetTester tester) {
  final headers = [
    for (final type in ['character', 'comic'])
      if (find.byKey(searchSectionKey(type)).evaluate().isNotEmpty)
        (
          type: type,
          dy: tester.getTopLeft(find.byKey(searchSectionKey(type))).dy,
        ),
  ]..sort((a, b) => a.dy.compareTo(b.dy));
  return [for (final header in headers) header.type];
}

/// Splits a step's comma-separated list (`'spi, amber'`).
List<String> listArgument(String text) => [
  for (final part in text.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  discoveryFixtureSets.forEach(McFixtureSets.register);
}
