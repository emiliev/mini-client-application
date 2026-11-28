// The skeleton's test templates: the test env, the steps the probe features
// use and the flow-scope test, written once (owned from then on). Raw text
// with `<<name>>` placeholders.

const envTemplate = r'''
/// The app's side of the feature contract, doubled (plan 05 §3.5). The
/// navigator has no methods: the flow ends with its result.
class Mock<<Navigator>> extends Mock implements <<Navigator>> {}

final Expando<List<<<Result>>?>> _results = Expando('<<module>> results');

/// Every result the flow completed with (`onComplete`), in order: the flow
/// result as the wiring would receive it.
List<<<Result>>?> flowResults() => _results[McTestSession.current] ??= [];

/// The flow as the app builds it, with a result recorder in place of the
/// route's pop.
Widget flowUnderTest() => <<Flow>>(
  navigator: Mock<<Navigator>>(),
  onComplete: flowResults().add,
);

/// The number of steps the flow has.
const int stepCount = <<step_count>>;

/// The key of the body of step [step] (0-based). It mirrors the feature's own
/// constant (plan 05 §3.5: steps find by key, never by the type of a feature
/// widget).
ValueKey<String> stepBodyKey(int step) =>
    ValueKey<String>('<<module>>.step.$step');

/// The key of the review's saving indicator.
const savingKey = ValueKey<String>('<<module>>.saving');

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

/// The user signs out from another screen: the real `AuthApi.signOut`,
/// inside `runAsync` (the session clears a real file, F-0038).
Future<void> endSessionElsewhere(WidgetTester tester) async {
  await tester.runAsync(() => diContainer<AuthApi>().signOut());
  await mcSettle(tester);
}

/// What the flow state holds, as the tests see it.
typedef FlowStateView = ({int step});

/// The flow's current state, through `mc_feature_flow`'s public test hook.
/// The state type is package-private (R4), so the hook is asked for
/// `dynamic`. [anchor] is any widget of the flow.
FlowStateView flowState(WidgetTester tester, Finder anchor) {
  expect(anchor, findsWidgets, reason: 'the flow is open');
  final dynamic state = flowStateOf<dynamic>(tester.element(anchor.first));
  return (step: state.step as int);
}

/// Any widget of the flow, on screen or not (an anchor for [flowState]).
Finder flowAnchor() => find.byType(Scaffold, skipOffstage: false);

/// Called once per suite by the BDD aggregator (`mc_bdd_tests(setup = ...)`).
void bddSetUpAll() {
<<setup>>}

/// The test root, once per test: the production-shaped container, unless an
/// earlier step such as `I am signed in as` made it.
Future<void> ensureContainer() async {
  final session = McTestSession.current;
  if (!session.containerInitialized) {
    await McTestContainer.initialize(session);
  }
}''';

/// Step files: (file name, usage, doc, parameters, body, imports).
class SkelStep {
  const SkelStep(this.name, this.usage, this.doc, this.params, this.body);

  final String name;
  final String usage;
  final String doc;
  final String params;
  final String body;
}

const flowScopeTestTemplate = r'''
void main() {
  setUpAll(<<setupAll>>);

  Future<void> signIn(WidgetTester tester) async {
    final session = McTestSession.current;
<<fixtures>>    await McTestContainer.initialize(session);
    await iAmSignedInAs(tester, '<<signed_in>>');
  }

  mcTestWidgets(
    "<<tag>> the flow's container resolves every registration",
    (tester) async {
      await signIn(tester);
      await initFlow(tester, flowUnderTest);
      await mcSettle(tester);

      final page = tester.element(find.byKey(stepBodyKey(0)));
      // Navigator, repository, bloc (no factory parameters).
      await page.debugResolveAll();
      await mcSettle(tester);
    },
  );

  mcTestWidgets(
    '<<tag>> a root without a forwarded type fails naming it',
    (tester) async {
      final session = McTestSession.current;
      // A root with Dio and Monitoring, but no session, which the flow
      // forwards.
      await initializeDIContainer([
        McDIInitializer((getIt, _) {
          getIt
            ..registerSingleton<Dio>(session.backend.backend.createDio())
            ..registerSingleton<Monitoring>(session.monitoring);
        }),
      ]);
      await tester.pumpWidget(
        McTestApp(session: session, home: flowUnderTest()),
      );
      await tester.pump();

      final error = tester.takeException();
      expect(error, isA<StateError>());
      expect('$error', contains('RootImport<SessionReader>'));
      expect(find.byKey(stepBodyKey(0)), findsNothing);
    },
  );

  mcTestWidgets(
    '<<tag>> every step page uses McAppBar with McFlowBackButton as leading',
    (tester) async {
      await signIn(tester);
      await initFlow(tester, flowUnderTest);
      await mcSettle(tester);
<<fills>>
      for (var step = 0; step < stepCount; step++) {
        final bar = tester.widget<McAppBar>(find.byType(McAppBar));
        expect(bar.leading, isA<McFlowBackButton>(), reason: 'step $step');
        if (step < stepCount - 1) {
          for (final (label, text) in fills[step]) {
            await enterText(tester, label, text);
          }
          await tester.tap(find.text('<<next>>'));
          await mcSettle(tester);
        }
      }
      expect(flowState(tester, flowAnchor()).step, stepCount - 1);
    },
  );
}''';
