// Generated once from the comics_details exemplar's step files by T-0072,
// then maintained by hand: the section-detail step templates (raw text with
// `<<name>>` placeholders and `«Ref»`s; see `tpl`). `doc` follows the
// `Usage:` line; `decl` is the function; `imports` are URIs the code uses
// without a reference (`BARREL` is the module's barrel).

class StepT {
  const StepT(this.doc, this.decl, this.imports);

  final String? doc;
  final String decl;
  final List<String> imports;
}

const stepTemplates = <String, StepT>{
  'open': StepT(
    r'''Enters the feature the way the app does: through its flow (barrel only),
with the navigator passed in the constructor [tide-nav §3.1].''',
    r'''Future<void> <<fn>>(WidgetTester tester, int id) async {
  await «<<envContainer>>»();
  await «initFlow»(tester, () => «<<envHost>>»(«<<envUnderTest>>»(id)));
  await «mcSettle»(tester);
}''',
    [],
  ),
  'open_two': StepT(
    r'''Two flows of the same <<item>>, one above the other (as two tabs or two
stacked routes would hold them), each with its own scope and blocs, over
one app root: one session, one bus, one backend.''',
    r'''Future<void> <<fn>>(WidgetTester tester, int id) async {
  await «<<envContainer>>»();
  Widget page(int n) => Expanded(
    child: KeyedSubtree(
      key: «<<envPageKey>>»(n),
      child: <<Prefix>>Flow(
        navigator: «<<envNavigator>>»(),
        <<idArg>>: <<IdType>>(id),
      ),
    ),
  );
  await «initFlow»(
    tester,
    () => «<<envHost>>»(Column(children: [page(1), page(2)])),
  );
  await «mcSettle»(tester);
}''',
    ['BARREL', 'package:flutter/widgets.dart'],
  ),
  'scroll_end': StepT(
    r'''Real drags until the <<page>> sits at its end, so every section has
been built and laid out.''',
    r'''Future<void> <<fn>>(WidgetTester tester) async {
  for (var drags = 0; drags < 50; drags++) {
    final position = tester
        .state<ScrollableState>(«<<envScrollable>>»().first)
        .position;
    if (position.pixels >= position.maxScrollExtent) {
      await «mcSettle»(tester);
      return;
    }
    await tester.drag(«<<envScrollable>>»().first, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('the <<scroll>> did not reach its end after 50 drags');
}''',
    ['package:flutter/widgets.dart'],
  ),
  'scroll_until': StepT(
    r'''Real drags of the <<page>> until [text] is on screen.''',
    r'''Future<void> <<fn>>(WidgetTester tester, String text) =>
    «<<envScrollUntil>>»(tester, find.text(text));''',
    [],
  ),
  'tap_on_page': StepT(
    r'''Taps the label on that page only (`I open <<item>> {id} on two pages`).''',
    r'''Future<void> <<fn>>(WidgetTester tester, String label, int page) async {
  final target = find
      .descendant(
        of: find.byKey(«<<envPageKey>>»(page)),
        matching: find.text(label),
      )
      .hitTestable();
  expect(target, findsOneWidget, reason: 'one tappable "$label" on page $page');
  await tester.tap(target);
  await «mcSettle»(tester);
}''',
    [],
  ),
  'page_shows': StepT(
    r'''The text is on that page (`I open <<item>> {id} on two pages`).''',
    r'''Future<void> <<fn>>(WidgetTester tester, int page, String text) async =>
    expect(
      find.descendant(
        of: find.byKey(«<<envPageKey>>»(page)),
        matching: find.text(text),
      ),
      findsOneWidget,
      reason: 'page $page shows "$text"',
    );''',
    [],
  ),
  'another_page': StepT(
    r'''Something else in the app (another page of the same <<item>>, another
feature) publishes `«DataChanged»(topic)` on the app's bus, as a favourite
write elsewhere does. Frames are pumped so a read it causes has started.''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  String topic,
) async {
  «diContainer»<«EventBus»>().publish(«DataChanged»(topic));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}''',
    [],
  ),
  'announced': StepT(
    r'''Exactly [count] `«DataChanged»(topic)` events reached a listener on the
app's `«EventBus»` since the <<item>> opened, and no other topic changed.''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  int count,
  String topic,
) async {
  final changes = «announcedChanges»();
  expect(
    changes.where((e) => e.topic == topic),
    hasLength(count),
    reason: 'DataChanged("$topic") events',
  );
  expect(
    changes.where((e) => e.topic != topic),
    isEmpty,
    reason: 'no other topic changed',
  );
}''',
    [],
  ),
  'sign_in_ok': StepT(
    r'''The app's side of `requestSignIn()`: the fixture user signs in through
the real `mc_api_auth` and `mc_session` (inside `runAsync`, because the
session saves to a real file, F-0038), then the pending request answers
true. Fails when the feature is not waiting for a sign-in.''',
    r'''Future<void> <<fn>>(WidgetTester tester, String email) async {
  final pending = «pendingSignIns»();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign in');
  final user = «fixtureUser»(email);
  final result = await tester.runAsync(
    () => «diContainer»<«AuthApi»>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
  pending.removeAt(0).complete(true);
  await «mcSettle»(tester);
}''',
    [],
  ),
  'sign_in_cancel': StepT(
    r'''The user backs out of the app's sign-in: the pending `requestSignIn()`
answers false. Fails when the feature is not waiting for a sign-in.''',
    r'''Future<void> <<fn>>(WidgetTester tester) async {
  final pending = «pendingSignIns»();
  expect(pending, isNotEmpty, reason: 'the feature asked to sign in');
  pending.removeAt(0).complete(false);
  await «mcSettle»(tester);
}''',
    [],
  ),
  'signs_in_elsewhere': StepT(
    r'''Someone signs in without this page asking (another screen of the app):
the real `«AuthApi»` and session, inside `runAsync` (the session saves to a
real file, F-0038). The page only hears of it through the session.''',
    r'''Future<void> <<fn>>(WidgetTester tester, String email) async {
  final user = «fixtureUser»(email);
  final result = await tester.runAsync(
    () => «diContainer»<«AuthApi»>().signIn(
      email: user.email,
      password: user.password,
    ),
  );
  expect(result?.getOrNull()?.id, user.id, reason: '$email signed in');
  await «mcSettle»(tester);
}''',
    [],
  ),
  'asked_sign_in': StepT(
    r'''`requestSignIn()` was called exactly [count] times (0: never).''',
    r'''Future<void> <<fn>>(WidgetTester tester, int count) async {
  final navigator = «<<envNavigator>>»();
  if (count == 0) {
    verifyNever(navigator.requestSignIn);
  } else {
    verify(navigator.requestSignIn).called(count);
  }
}''',
    ['package:mocktail/mocktail.dart'],
  ),
  'session_ends': StepT(
    r'''The user signs out from another screen: the real `«AuthApi».signOut`, inside
`runAsync` (the session clears a real file, F-0038).''',
    r'''Future<void> <<fn>>(WidgetTester tester) async {
  await tester.runAsync(() => «diContainer»<«AuthApi»>().signOut());
  await «mcSettle»(tester);
}''',
    [],
  ),
  'signed_out': StepT(
    r'''The app's session holds nobody.''',
    r'''Future<void> <<fn>>(WidgetTester tester) async {
  final session = «diContainer»<«SessionReader»>();
  expect(session.isSignedIn, isFalse);
  expect(session.accessToken, isNull);
}''',
    [],
  ),
  'toggle_on': StepT(
    r'''Exactly one button shows [label], it takes taps, and a screen reader hears
it as a toggle that is on (the `Semantics(toggled:)` around the button).''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  String label,
) async {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );
  expect(button, findsOneWidget, reason: 'one button labelled "$label"');
  expect(tester.widget<ButtonStyleButton>(button).enabled, isTrue);
  final toggles = find.ancestor(
    of: button,
    matching: find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.toggled != null,
    ),
  );
  expect(
    tester.widget<Semantics>(toggles.first).properties.toggled,
    isTrue,
    reason: 'the toggle is announced as on',
  );
}''',
    ['package:flutter/material.dart'],
  ),
  'is_fav': StepT(
    r'''The backend holds the favourite for that user: the write reached the
identity domain under their bearer.''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  int <<item>>,
  String email,
) async {
  final response = await «favouritesProbe»(tester, email, 'GET', <<item>>);
  expect(response.statusCode, 200, reason: '<<item>> $<<item>> is a favourite');
}''',
    [],
  ),
  'not_fav': StepT(
    r'''The backend holds no such favourite for that user (`404 not_favourite`).''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  int <<item>>,
  String email,
) async {
  final response = await «favouritesProbe»(tester, email, 'GET', <<item>>);
  expect(response.statusCode, 404, reason: '<<item>> $<<item>> is not a favourite');
}''',
    [],
  ),
  'has_fav': StepT(
    r'''Seeds the backend before the page opens, as another device would have.''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  String email,
  int <<item>>,
) async {
  final response = await «favouritesProbe»(tester, email, 'PUT', <<item>>);
  expect(response.statusCode, 200, reason: 'seeded <<item>> $<<item>>');
}''',
    [],
  ),
  'fact_reads': StepT(
    r'''In the facts section, the row labelled [label] shows exactly [value]
(non-breaking spaces read as spaces: intl writes `3,99 $` with one).''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  String label,
  String value,
) async {
  final facts = find.byKey(«<<factsKey>>»);
  await «<<envScrollUntil>>»(tester, facts);
  final labelText = find.descendant(of: facts, matching: find.text(label));
  expect(labelText, findsOneWidget, reason: 'one fact is labelled "$label"');
  final row = find.ancestor(of: labelText, matching: find.byType(Row)).first;
  final texts = [
    for (final element
        in find.descendant(of: row, matching: find.byType(Text)).evaluate())
      «plainSpaces»((element.widget as Text).data!),
  ];
  expect(texts, [label, «plainSpaces»(value)], reason: 'the "$label" fact');
}''',
    ['package:flutter/material.dart'],
  ),
  'fact_reads_exact': StepT(
    r'''In the facts section, the row labelled [label] shows exactly [value].''',
    r'''Future<void> <<fn>>(
  WidgetTester tester,
  String label,
  String value,
) async {
  final facts = find.byKey(«<<factsKey>>»);
  await «<<envScrollUntil>>»(tester, facts);
  final labelText = find.descendant(of: facts, matching: find.text(label));
  expect(labelText, findsOneWidget, reason: 'one fact is labelled "$label"');
  final row = find.ancestor(of: labelText, matching: find.byType(Row)).first;
  final texts = [
    for (final element
        in find.descendant(of: row, matching: find.byType(Text)).evaluate())
      (element.widget as Text).data!,
  ];
  expect(texts, [label, value], reason: 'the "$label" fact');
}''',
    ['package:flutter/material.dart'],
  ),
};
