import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_reading_list_editor/library_reading_list_editor.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_media/mc_ds_media.dart';
import 'package:mc_event_bus/mc_event_bus.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_fixtures_comics/mc_fixtures_comics.dart';
import 'package:mc_fixtures_identity/mc_fixtures_identity.dart';
import 'package:mc_fixtures_library/mc_fixtures_library.dart';
import 'package:mc_fixtures_media/mc_fixtures_media.dart';
import 'package:mc_test_steps/mc_test_steps.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mocktail/mocktail.dart';

/// The app's side of the feature contract, doubled (plan 05 §3.5).
class MockReadingListEditorNavigator extends Mock
    implements ReadingListEditorNavigator {}

final Expando<MockReadingListEditorNavigator> _navigators = Expando(
  'reading_list_editor navigator',
);
final Expando<List<Completer<bool>>> _signIns = Expando(
  'reading_list_editor sign-ins',
);
final Expando<List<ReadingListId?>> _results = Expando(
  'reading_list_editor results',
);
final Expando<List<DataChanged>> _changes = Expando(
  'reading_list_editor changes',
);
final Expando<bool> _observed = Expando('reading_list_editor observers');

/// The running test's navigator mock: one per test, keyed by its session.
/// `requestSignIn` answers with a pending future that a later step settles
/// (`signing in succeeds as` / `signing in is cancelled`), so a scenario can
/// look at the editor while it waits for the app (F-0040 fact 3).
MockReadingListEditorNavigator editorNavigator() =>
    _navigators[McTestSession.current] ??= _newNavigator();

MockReadingListEditorNavigator _newNavigator() {
  final navigator = MockReadingListEditorNavigator();
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

/// Every result the flow completed with (`onComplete`), in order: the flow
/// result as the wiring would receive it.
List<ReadingListId?> editorResults() => _results[McTestSession.current] ??= [];

/// Every `DataChanged` published on the bus since the editor opened.
List<DataChanged> announcedChanges() => _changes[McTestSession.current] ??= [];

/// The test root, once per test: the production-shaped container (unless an
/// earlier step such as `I am signed in as` made it), plus a listener on the
/// bus. Called by the steps that open the editor.
Future<void> ensureEditorContainer() async {
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

/// The flow as the app builds it, over the session's navigator mock, with a
/// result recorder in place of the route's pop.
Widget editorFlowUnderTest({String? editing}) => ReadingListEditorFlow(
  navigator: editorNavigator(),
  editing: editing == null ? null : ReadingListId(editing),
  onComplete: editorResults().add,
);

/// What every test host provides above a flow: the bundled-art resolver and
/// the fixture asset bundle (the app root does this in production).
Widget editorTestHost(Widget flow, {AssetBundle? bundle}) => McMediaScope(
  resolver: const BundledImageResolver(),
  child: DefaultAssetBundle(
    bundle: bundle ?? McFixtureAssetBundle(),
    child: flow,
  ),
);

/// The feature's string keys (plan 05 §3.5: steps find by key, never by the
/// type of a feature widget). They mirror the feature's own constants.
const detailsBodyKey = ValueKey<String>('reading_list_editor.details');
const visibilityKey = ValueKey<String>('reading_list_editor.visibility');
const closeEditorKey = ValueKey<String>('reading_list_editor.close');
const comicResultsKey = ValueKey<String>('reading_list_editor.results');
const pickedComicsKey = ValueKey<String>('reading_list_editor.picked');
const comicsErrorKey = ValueKey<String>('reading_list_editor.comics.error');
const reviewBodyKey = ValueKey<String>('reading_list_editor.review');
const saveErrorKey = ValueKey<String>('reading_list_editor.save.error');
const savingKey = ValueKey<String>('reading_list_editor.saving');

/// The key of the search result for comic [id].
ValueKey<String> comicRowKey(int id) =>
    ValueKey<String>('reading_list_editor.result.$id');

/// The text field labelled [label] (its `McTextField`'s `TextField`).
Finder textFieldLabelled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(TextField),
);

/// Replaces the text of the field labelled [label], as typing does, then
/// moves the focus away so the field reports it was touched.
Future<void> enterText(WidgetTester tester, String label, String text) async {
  final field = textFieldLabelled(label).hitTestable();
  expect(field, findsOneWidget, reason: 'one field labelled "$label"');
  await tester.enterText(field, text);
  await mcSettle(tester);
  FocusManager.instance.primaryFocus?.unfocus();
  await mcSettle(tester);
}

/// The field labelled [label] shows [text].
void expectFieldText(WidgetTester tester, String label, String text) {
  final field = textFieldLabelled(label);
  expect(field, findsOneWidget, reason: 'one field labelled "$label"');
  expect(tester.widget<TextField>(field).controller!.text, text);
}

/// [text] shows as the error of the field labelled [label].
void expectErrorUnder(WidgetTester tester, String label, String text) {
  final field = textFieldLabelled(label);
  expect(field, findsOneWidget, reason: 'one field labelled "$label"');
  final decoration = tester.widget<TextField>(field).decoration!;
  final error = decoration.error;
  expect(error, isNotNull, reason: '"$label" shows an error');
  expect(
    find.descendant(of: find.byWidget(error!), matching: find.text(text)),
    findsOneWidget,
    reason: 'the error under "$label"',
  );
}

/// Taps the icon button whose tooltip (and accessible name) is [label].
Future<void> tapTooltip(WidgetTester tester, String label) async {
  final button = find.byTooltip(label);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button.hitTestable());
  await mcSettle(tester);
}

/// The `title` column of [table].
List<String> titlesOf(DataTable table) => [
  for (final row in table.asMaps()) row['title']! as String,
];

/// Step 3's comics, top to bottom, by their "Move … up" arrows.
List<String> readingOrder(WidgetTester tester) {
  final arrows = find.descendant(
    of: find.byKey(reviewBodyKey),
    matching: find.byType(Tooltip),
  );
  final rows = <({double y, String title})>[];
  for (final element in arrows.evaluate()) {
    final message = (element.widget as Tooltip).message ?? '';
    final match = RegExp(r'^Move (.+) up$').firstMatch(message);
    if (match != null) {
      rows.add((y: tester.getTopLeft(find.byWidget(element.widget)).dy, title: match.group(1)!));
    }
  }
  rows.sort((a, b) => a.y.compareTo(b.y));
  return [for (final row in rows) row.title];
}

/// What the flow state holds, as the tests see it.
typedef FlowStateView = ({ReadingListId? editing, int step});

/// The flow's current state, through `mc_feature_flow`'s public test hook.
/// The state type is package-private (R4), so the hook is asked for
/// `dynamic`. [anchor] is any widget of the flow.
FlowStateView editorFlowState(WidgetTester tester, Finder anchor) {
  expect(anchor, findsWidgets, reason: 'the editor flow is open');
  final dynamic state = flowStateOf<dynamic>(tester.element(anchor.first));
  return (
    editing: state.editing as ReadingListId?,
    step: state.step as int,
  );
}

/// Test-facing facts come from the fixture packages (their CONTRACT.md
/// files), never from feature code.
final ComicUniverse comicUniverse = ComicUniverse(42);

/// The comic titled [title] in the comics fixture.
ComicRecord comicTitled(String title) => comicUniverse.allSeries
    .expand((s) => s.comicIds)
    .map((id) => comicUniverse.findComic(id)!)
    .firstWhere(
      (c) => c.title == title,
      orElse: () => throw ArgumentError.value(title, 'title', 'no such comic'),
    );

/// The fixture user with [email].
FixtureUser fixtureUser(String email) => fixtureUsers.firstWhere(
  (u) => u.email == email,
  orElse: () => throw ArgumentError.value(email, 'email', 'no fixture user'),
);

/// Talks to the backend's library domain directly, as [email], with a token
/// of the fixture's shape: a second client that reads or seeds what the
/// backend holds. It bypasses the app's `Dio` and the harness, so it adds no
/// request to what the scenario asserts on.
Future<Response<Object?>> libraryProbe(
  WidgetTester tester,
  String email,
  String method,
  String path, {
  Object? body,
}) async {
  final user = fixtureUser(email);
  final dio = McTestSession.current.backend.backend.createDio();
  final response = await tester.runAsync(
    () => dio.request<Object?>(
      path,
      data: body,
      options: Options(
        method: method,
        headers: {'Authorization': 'Bearer ${mintAccessToken(user.id, 9999)}'},
        validateStatus: (_) => true,
      ),
    ),
  );
  return response!;
}

/// The list [id] of [email] as the backend holds it (`GET`), decoded.
Future<Map<String, dynamic>> storedList(
  WidgetTester tester,
  String email,
  String id,
) async {
  final response = await libraryProbe(tester, email, 'GET', '/v1/me/lists/$id');
  expect(response.statusCode, 200, reason: '$email has list $id');
  final data = response.data;
  return (data is String ? jsonDecode(data) : data)! as Map<String, dynamic>;
}

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
  comicsFixtureSets.forEach(McFixtureSets.register);
  identityFixtureSets.forEach(McFixtureSets.register);
  libraryFixtureSets.forEach(McFixtureSets.register);
}
