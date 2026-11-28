// The first-write templates of a paged search module (see skeleton.dart).
// Plain Dart with `<<name>>` variables, written once and owned afterwards.

import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/emit/feature_search/model.dart';
import 'package:mcgen/src/emit/feature_search/tests.dart';
import 'package:mcgen/src/emit/feature_search/text.dart';

const skelApi = r'''
/// The feature's own retrofit API on the shared `Dio` (Tide: one per
/// feature). The `Dio` comes from the root container (a `RootImport`).
///
/// Paths are relative (no leading `/`): `AppConfig.apiBaseUrl` ends with `/`.
@injectable
@RestApi()
abstract class <<Pascal>>Api {
  @factoryMethod
  factory <<Pascal>>Api(Dio dio) = _<<Pascal>>Api;

  /// One page of the <<items>> whose <<title>> starts with [prefix].
  @GET('<<path>>')
  Future<ApiPage<<<Dto>>>> getPage({
    @Query('<<prefixParam>>') required String prefix,
    @Query('orderBy') required String orderBy,
    @Query('offset') int offset = 0,
    @Query('limit') int limit = <<pageSize>>,
  });
}''';

const skelDto = r'''
/// A <<entity>> summary as the list endpoint sends it (CONTRACT.md of
/// `<<fixturePackage>>`).
///
/// The JSON flags are spelled out (R30): under the Bazel shim a bare
/// `@freezed` silently loses its JSON (F-0025).
@Freezed(fromJson: true, toJson: true)
abstract class <<Dto>> with _$<<Dto>> {
  @JsonSerializable(explicitToJson: true)
  const factory <<Dto>>({
    required int id,
    required String <<title>>,
    required <<ImageDto>> <<image>>,
  }) = _<<Dto>>;

  factory <<Dto>>.fromJson(Map<String, dynamic> json) =>
      _$<<Dto>>FromJson(json);
}

/// An image: a path plus its variant's wire name.
@Freezed(fromJson: true, toJson: true)
abstract class <<ImageDto>> with _$<<ImageDto>> {
  const factory <<ImageDto>>({required String path, required String variant}) =
      _<<ImageDto>>;

  factory <<ImageDto>>.fromJson(Map<String, dynamic> json) =>
      _$<<ImageDto>>FromJson(json);
}''';

const skelEntity = r'''
/// A <<entity>> as this feature shows it. Domain model: no JSON, so a bare
/// `@freezed` (R30 is about models with JSON); the wire shape is `<<Dto>>`.
@freezed
abstract class <<Entity>> with _$<<Entity>> {
  const factory <<Entity>>({
    required <<Id>> id,
    required String <<title>>,
    required ApiImage <<image>>,
  }) = _<<Entity>>;
}''';

const skelMapper = r'''
/// Wire to domain. An unknown variant name throws a `FormatException`, which
/// the repository's `apiCall` turns into `ApiMalformed`.
extension <<Dto>>Mapper on <<Dto>> {
  <<Entity>> toDomain() =>
      <<Entity>>(id: <<Id>>(id), <<title>>: <<title>>, <<image>>: <<image>>.toDomain());
}

extension <<ImageDto>>Mapper on <<ImageDto>> {
  ApiImage toDomain() =>
      ApiImage(path: path, variant: ImageVariant.fromWire(variant));
}

/// The envelope as the paging kit's [Page].
extension <<Entity>>PageMapper on ApiPage<<<Dto>>> {
  Page<<<Entity>>> toDomain() => Page(
    offset: offset,
    limit: limit,
    total: total,
    results: [for (final dto in results) dto.toDomain()],
  );
}''';

const skelFacets = r'''
/// The orders the backend sorts <<items>> in (`orderBy`, CONTRACT.md of
/// `<<fixturePackage>>`); the list always ends on the id, so each is total.
enum <<Sort>> {
<<sortValues>>;

  const <<Sort>>(this.wireName);

  /// The `orderBy` value.
  final String wireName;
}

/// What narrows and orders a search besides the typed prefix. A change of
/// either sends one new request from the first page.
final class <<Facets>> {
  const <<Facets>>({this.sort = <<Sort>>.<<defaultSort>>});

  final <<Sort>> sort;

  <<Facets>> withSort(<<Sort>> sort) => <<Facets>>(sort: sort);

  @override
  bool operator ==(Object other) => other is <<Facets>> && other.sort == sort;

  @override
  int get hashCode => sort.hashCode;

  @override
  String toString() => '<<Facets>>(sort: $sort)';
}

/// What the search asks the backend for: one page of the <<items>> whose
/// <<title>> starts with [prefix], ordered by [facets].
final class <<Query>> {
  const <<Query>>({
    required this.prefix,
    required this.facets,
    required this.offset,
    required this.limit,
  });

  final String prefix;
  final <<Facets>> facets;
  final int offset;
  final int limit;
}''';

const skelRepository = r'''
/// Pages of matching <<items>> as values, never exceptions. Stateless
/// (Tide): which query and facets are on screen live in the bloc.
@injectable
class <<Repository>> {
  const <<Repository>>(this._api);

  final <<Pascal>>Api _api;

  Future<Result<Page<<<Entity>>>, ApiFailure>> fetchPage(
    <<Query>> query,
  ) => apiCall(
    () async => (await _api.getPage(
      prefix: query.prefix,
      orderBy: query.facets.sort.wireName,
      offset: query.offset,
      limit: query.limit,
    )).toDomain(),
  );
}''';

const skelTile = r'''
/// A result's thumbnail, portrait (3:4).
const double <<entity>>ResultArtWidth = 36;
const double <<entity>>ResultArtHeight = 48;

/// The key of [<<tileArg>>]'s row, for tests: `<<module>>.result.<id>`.
ValueKey<String> <<entity>>ResultKey(<<Entity>> <<tileArg>>) =>
    ValueKey<String>('<<module>>.result.${<<tileArg>>.id.value}');

/// One result: its art and its <<title>>. A tap hands it over to the app
/// (through the bloc).
class <<Tile>> extends StatelessWidget {
  const <<Tile>>({required this.<<tileArg>>, super.key});

  final <<Entity>> <<tileArg>>;

  @override
  Widget build(BuildContext context) => ListTile(
    key: <<entity>>ResultKey(<<tileArg>>),
    leading: McImage(
      image: <<tileArg>>.<<image>>,
      variant: ImageVariant.portraitSmall,
      width: <<entity>>ResultArtWidth,
      height: <<entity>>ResultArtHeight,
    ),
    title: Text(<<tileArg>>.<<title>>),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.read<<<Pascal>>Bloc>().add(
      <<Pascal>>Event.open(<<tileArg>>.id),
    ),
  );
}''';

const skelFacetsView = r'''
/// Key of the sort chips, for tests.
const searchSortKey = ValueKey<String>('<<module>>.facets.sort');

/// The facets over the results: how to sort. The group is one scrolling row,
/// so a long list of chips and a large text size never overflow. A choice
/// goes to the bloc, which searches the same query again from the first
/// page.
class <<FacetsView>> extends StatelessWidget {
  const <<FacetsView>>({required this.facets, super.key});

  final <<Facets>> facets;

  @override
  Widget build(BuildContext context) {
    final l10n = <<L10n>>.of(context);
    final bloc = context.read<<<Pascal>>Bloc>();
    String sortLabel(<<Sort>> sort) => switch (sort) {
<<sortLabels>>
    };
    return Semantics(
      container: true,
      label: l10n.<<camel>>SortLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: McInsets.horizontal,
        child: McChipGroup<<<Sort>>>.single(
          key: searchSortKey,
          options: [
            for (final sort in <<Sort>>.values)
              McChipOption(value: sort, label: sortLabel(sort)),
          ],
          selected: facets.sort,
          onChanged: (picked) => bloc.add(
            <<Pascal>>Event.sortChanged(picked ?? <<Sort>>.<<defaultSort>>),
          ),
        ),
      ),
    );
  }
}''';

const skelEmpty = r'''
/// What the empty view says when nothing matched [query]. Shared by the
/// `empty` state and the paged list's own empty view.
String emptySearchMessage(<<L10n>> l10n, String query) =>
    l10n.<<camel>>EmptyMessage(query);''';

// --- tests ------------------------------------------------------------------

DartLibrary skelEnv(SrModel m, Map<String, String> v) {
  final firstWire = m.sorts.first.$2;
  return DartLibrary(
    envPath(m),
    imports: [
      'package:${m.module}/${m.module}.dart',
      'package:flutter/material.dart',
      'package:flutter_test/flutter_test.dart',
      'package:mc_ds_feedback/mc_ds_feedback.dart',
      'package:mc_ds_inputs/mc_ds_inputs.dart',
      'package:mc_ds_media/mc_ds_media.dart',
      'package:${v['fixturePackage']}/${v['fixturePackage']}.dart',
      'package:mc_fixtures_media/mc_fixtures_media.dart',
      'package:mc_test_steps/mc_test_steps.dart',
      'package:mc_test_utils/mc_test_utils.dart',
      'package:mocktail/mocktail.dart',
    ],
    decls: [
      RawDecl(Code(tpl(_env, {...v, 'firstWire': firstWire}))),
    ],
  );
}

DartLibrary skelFlowScopeTest(SrModel m, Map<String, String> v) {
  return DartLibrary(
    'test/flow_scope_test.dart',
    preamble: commentLines(
      'The flow as a unit of wiring, entered through the barrel only. R17: its\n'
      'hand-written root imports (lib/src/di/flow_scope.dart) are complete, and a\n'
      'missing one fails at flow creation, naming the type (`mcgen wire` will\n'
      'generate the list, Phase D). The flow is immutable after creation: a new\n'
      'initial query builds a new flow.',
    ),
    imports: [
      'package:dio/dio.dart',
      'package:${m.module}/${m.module}.dart',
      'package:flutter/material.dart',
      'package:flutter_test/flutter_test.dart',
      'package:mc_di/mc_di.dart',
      'package:mc_ds_navigation/mc_ds_navigation.dart',
      'package:mc_feature_flow/mc_feature_flow.dart',
      'package:mc_feature_flow/testing.dart',
      'package:mc_monitoring/mc_monitoring.dart',
      'package:mc_test_utils/mc_test_utils.dart',
      'path:${envPath(m)}',
    ],
    decls: [
      RawDecl(
        Code(
          tpl(_flowScopeTest, {
            ...v,
            'pageTitle': m.en(m.key('Title')),
            'prefixParam': v['prefixParam']!,
          }),
        ),
      ),
    ],
  );
}

DartLibrary skelContractTest(SrModel m, Map<String, String> v) {
  return DartLibrary(
    'test/contract/${m.module}_api_contract_test.dart',
    preamble: commentLines(
      'Contract tests are the one place a feature test reaches `src/` (R7).',
    ),
    imports: [
      m.uri('domain/api/${m.module}_api.dart'),
      m.uri('domain/model/${m.file('facets')}'),
      m.uri('domain/model/${m.ids.first.file}'),
      m.uri('domain/repository/${m.module}_repository.dart'),
      'package:flutter_test/flutter_test.dart',
      'package:${v['fixturePackage']}/${v['fixturePackage']}.dart',
      'package:mc_mocked_backend/mc_mocked_backend.dart',
    ],
    decls: [RawDecl(Code(tpl(_contract, v)))],
  );
}

const _contract = r'''
void main() {
  group('<<Repository>> over the fixture backend', () {
    test('a prefix page is the fixture records, in order, with its total',
        () async {
      final backend = MockBackend(domains: [const <<Domain>>()]);
      final repository = <<Repository>>(<<Pascal>>Api(backend.createDio()));

      final result = await repository.fetchPage(
        const <<Query>>(
          prefix: '<<exampleQuery>>',
          facets: <<Facets>>(),
          offset: 0,
          limit: <<pageSize>>,
        ),
      );

      final page = result.getOrNull()!;
      final expected = [
        for (final r in <<records>>)
          if (r.<<title>>.toLowerCase().startsWith('<<exampleQuery>>')) r,
      ];
      expect(expected, isNotEmpty);
      expect(page.total, expected.length);
      expect(page.offset, 0);
      expect(page.limit, <<pageSize>>);
      expect(
        [for (final c in page.results) c.id],
        [for (final r in expected.take(<<pageSize>>)) <<Id>>(r.id)],
      );
      expect(
        [for (final c in page.results) c.<<title>>],
        [for (final r in expected.take(<<pageSize>>)) r.<<title>>],
      );
    });
  });
}''';

const _flowScopeTest = r'''
void main() {
  setUpAll(bddSetUpAll);

  void serveSearch() =>
      McTestSession.current.backend.useFixtureSet('<<fixtureSet>>');

  mcTestWidgets(
    "<<tag>>the flow's container resolves every registration",
    (tester) async {
      serveSearch();
      await openSearch(tester, initialQuery: '<<exampleQuery>>');

      final page = tester.element(find.byKey(searchFieldKey));
      // Navigator, API, repository, the history (module) and the bloc.
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    '<<tag>>a new initialQuery builds a new flow that searches it',
    (tester) async {
      serveSearch();
      final query = ValueNotifier<String>('<<exampleQuery>>');
      addTearDown(query.dispose);
      await initFlow(
        tester,
        () => ValueListenableBuilder<String>(
          valueListenable: query,
          builder: (context, q, _) => searchTestHost(
            <<Flow>>(navigator: searchNavigator(), initialQuery: q),
          ),
        ),
      );
      await letStorageFinish(tester);
      final first = tester.element(find.byKey(searchFieldKey));
      expect((flowStateOf<dynamic>(first) as dynamic).initialQuery, '<<exampleQuery>>');
      expect(find.text('<<exampleTitle>>'), findsOneWidget);

      query.value = 'zzzz';
      await letStorageFinish(tester);

      final second = tester.element(find.byKey(searchFieldKey));
      expect((flowStateOf<dynamic>(second) as dynamic).initialQuery, 'zzzz');
      expect(tester.widget<EditableText>(searchField()).controller.text, 'zzzz');
      expect(find.text('<<exampleTitle>>'), findsNothing);
      expect(
        [
          for (final r in McTestSession.current.backend.requests)
            r.query['<<prefixParam>>'],
        ],
        ['<<exampleQuery>>', 'zzzz'],
      );
    },
  );

  mcTestWidgets(
    '<<tag>>a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with Dio and Monitoring, but no FileStore, which the flow
      // forwards (the recent searches).
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
            ..registerSingleton<Dio>(session.backend.backend.createDio())
            ..registerSingleton<Monitoring>(session.monitoring);
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(
          session: session,
          home: searchTestHost(searchFlowUnderTest()),
        ),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<FileStore>'));
      expect(find.byKey(searchFieldKey), findsNothing);
    },
  );

  mcTestWidgets(
    '<<tag>>the search page uses McAppBar with McFlowBackButton as leading',
    (tester) async {
      serveSearch();
      await openSearch(tester);

      final bar = tester.widget<McAppBar>(find.byType(McAppBar));
      expect(bar.leading, isA<McFlowBackButton>());
      expect(bar.title, '<<pageTitle>>');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(McFlowBackButton),
        ),
        findsOneWidget,
      );
    },
  );
}''';

const _env = r'''
/// The app's side of the feature contract, doubled (plan 05 §3.5).
class <<MockNavigator>> extends Mock implements <<Navigator>> {}

final Expando<<<MockNavigator>>> _navigators = Expando(
  '<<module>> navigator',
);

/// The running test's navigator mock: one per test, keyed by its session, so
/// nothing leaks between scenarios. `void` methods need no stub.
<<MockNavigator>> searchNavigator() =>
    _navigators[McTestSession.current] ??= <<MockNavigator>>();

/// The feature's string keys (plan 05 §3.5: steps find by key, never by type
/// of a feature widget).
const searchFieldKey = ValueKey<String>('<<module>>.field');
const searchResultsKey = ValueKey<String>('<<module>>.results');
const searchSortKey = ValueKey<String>('<<module>>.facets.sort');
const searchHistoryKey = ValueKey<String>('<<module>>.history');
const String searchResultKeyPrefix = '<<module>>.result.';

/// Test-facing facts come from the fixture package (its CONTRACT.md), never
/// from feature code: the records of the default set, in `<<firstWire>>` order.
final List<<<Record>>> defaultRecords = <<records>>;

/// How many <<items>> one request asks for (`limit`).
const int searchPageSize = <<pageSize>>;

/// The <<items>> whose <<title>> starts with [prefix] (any case), in the order
/// of the `orderBy` value [order]: what the backend answers, worked out here
/// from the fixture's records.
List<<<Record>>> matchesOf(String prefix, {String order = '<<firstWire>>'}) {
  final lower = prefix.trim().toLowerCase();
  final matches = [
    for (final r in defaultRecords)
      if (r.<<title>>.toLowerCase().startsWith(lower)) r,
  ];
  return order.startsWith('-') ? matches.reversed.toList() : matches;
}

/// The record titled [title].
<<Record>> <<lookup>>(String title) =>
    defaultRecords.firstWhere((r) => r.<<title>> == title);

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
Widget searchFlowUnderTest({String? initialQuery}) => <<Flow>>(
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
typedef ShownResult = ({int id, String title, ImageProvider? art});

final RegExp _resultKey = RegExp(r'^<<module>>\.result\.(\d+)$');

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
          title: (tile.title! as Text).data!,
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

/// Taps the result row titled [title] [times] times, [between] of fake time
/// apart (zero: within one frame), then settles.
Future<void> tapResult(
  WidgetTester tester,
  String title, {
  int times = 1,
  Duration between = Duration.zero,
}) async {
  final row = find.descendant(
    of: find.byKey(searchResultsKey),
    matching: find.text(title),
  );
  await tester.scrollUntilVisible(row, 200, scrollable: resultsScrollable());
  await mcSettle(tester);
  expect(row.hitTestable(), findsOneWidget, reason: 'one "$title" row');
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
  <<fixtureSets>>.forEach(McFixtureSets.register);
}''';
