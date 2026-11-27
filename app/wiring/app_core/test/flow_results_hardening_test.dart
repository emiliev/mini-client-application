// T-0054: the flow-result machinery under a guard, under overlays and with
// extras (P-094 to P-096). The T-0048 and T-0049 tests (flow_results_test)
// stay as they were.
import 'dart:async';
import 'dart:convert';

import 'package:app_core/app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/src/logging.dart' as go_router_log;

const _finish = Key('finish');
const _finishEmpty = Key('finish.empty');
const _signIn = Key('signin.go_from');
const _signInPop = Key('signin.pop_value');
const _signInPopTrue = Key('signin.pop_true');
const _home = Key('home');

class _FakeFlow extends StatelessWidget {
  const _FakeFlow({required this.onComplete});

  final ValueChanged<String?> onComplete;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        key: _finish,
        onPressed: () => onComplete('l-5'),
        child: const Text('finish'),
      ),
      TextButton(
        key: _finishEmpty,
        onPressed: () => onComplete(null),
        child: const Text('finish empty'),
      ),
    ],
  );
}

/// The `/me/**` sign-in guard of plan 01 §4.2, as a test-only `redirect`:
/// signed out, `/me/...` goes to `/signin?from=<location>`; signing in goes
/// to `from` with `go`, which replaces the page the guard showed.
class _App {
  _App(this.router, this.signedIn, this.tick);

  final GoRouter router;
  final ValueNotifier<bool> signedIn;

  /// A refreshListenable that is not the guard's: bumping it re-parses.
  final ValueNotifier<int> tick;

  /// What the callers of [open] got, in order.
  final List<String?> got = [];

  /// The same, tagged `c:` (create) or `e:` (edit), for tests with two calls.
  final List<String> tagged = [];

  void create() => unawaited(
    AppFlows.createReadingList(router).then((v) => tagged.add('c:$v')),
  );

  void edit(String id) => unawaited(
    AppFlows.editReadingList(router, id).then((v) => tagged.add('e:$v')),
  );

  Future<void> open(WidgetTester tester) async {
    unawaited(AppFlows.createReadingList(router).then(got.add));
    await tester.pumpAndSettle();
  }
}

Future<_App> _app(
  WidgetTester tester, {
  bool signedIn = true,
  String initial = '/',

  /// When set, the guard of `/me/**` answers after this long (an async
  /// redirect, as the planned sign-in guard will).
  Duration? guardDelay,
}) async {
  final state = ValueNotifier<bool>(signedIn);
  final tick = ValueNotifier<int>(0);
  addTearDown(state.dispose);
  addTearDown(tick.dispose);
  final router = GoRouter(
    initialLocation: initial,
    refreshListenable: Listenable.merge([state, tick]),
    redirect: (context, s) {
      String? target() {
        if (!state.value && s.uri.path.startsWith('/me/')) {
          return '/signin?from=${Uri.encodeComponent(s.uri.toString())}';
        }
        return null;
      }

      if (guardDelay != null && s.uri.path.startsWith('/me/')) {
        return Future<String?>.delayed(guardDelay, target);
      }
      return target();
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, s) => const Text('home', key: _home),
      ),
      GoRoute(path: '/other', builder: (context, s) => const Text('other')),
      GoRoute(
        path: '/signin',
        builder: (context, s) => Column(
          children: [
            TextButton(
              key: _signIn,
              onPressed: () {
                state.value = true;
                GoRouter.of(context).go(s.uri.queryParameters['from']!);
              },
              child: const Text('sign in'),
            ),
            TextButton(
              key: _signInPopTrue,
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('pop true'),
            ),
            TextButton(
              key: _signInPop,
              onPressed: () => Navigator.of(context).pop('signed'),
              child: const Text('pop with a value'),
            ),
          ],
        ),
      ),
      GoRoute(
        path: AppLocations.newReadingList,
        builder: (context, s) => FlowResultRoute<String>(
          extra: s.extra,
          builder: (complete) => _FakeFlow(onComplete: complete),
        ),
      ),
      GoRoute(
        path: '/me/lists/:id/edit',
        builder: (context, s) => FlowResultRoute<String>(
          extra: s.extra,
          builder: (complete) => _FakeFlow(
            onComplete: (_) => complete(s.pathParameters['id']),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return _App(router, state, tick);
}

/// Opens a dialog over the screen that shows [_finish].
NavigatorState _dialog(WidgetTester tester) {
  final context = tester.element(find.byKey(_finish));
  unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => const Text('dialog', key: Key('dialog')),
    ),
  );
  return Navigator.of(context);
}

void main() {
  group('T-0054-AC1 every call completes exactly once', () {
    testWidgets('T-0054-AC1 with a result', (tester) async {
      final app = await _app(tester);
      await app.open(tester);

      await tester.tap(find.byKey(_finish));
      await tester.pumpAndSettle();
      app.router.go(AppLocations.editReadingList('l-3'));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0054-AC1 with Back', (tester) async {
      final app = await _app(tester);
      await app.open(tester);

      app.router.pop();
      await tester.pumpAndSettle();
      app.router.go(AppLocations.editReadingList('l-3'));
      await tester.pumpAndSettle();

      expect(app.got, [null]);
    });

    testWidgets('T-0054-AC1 when a go replaces the route', (tester) async {
      final app = await _app(tester);
      await app.open(tester);

      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();
      app.router.go(AppLocations.newReadingList);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0054-AC1 when the route is disposed', (tester) async {
      final app = await _app(tester);
      await app.open(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(app.got, [null]);
    });

    testWidgets('T-0054-AC1 a guard redirect, then go(from): the caller gets '
        'null once and nothing asserts', (tester) async {
      final app = await _app(tester, signedIn: false);
      await app.open(tester);
      expect(find.byKey(_signIn), findsOneWidget, reason: 'the guard');
      expect(app.got, isEmpty);

      await tester.tap(find.byKey(_signIn));
      await tester.pumpAndSettle();

      expect(find.byKey(_finish), findsOneWidget, reason: 'the flow shows');
      expect(app.got, [null], reason: 'its push was replaced by the go');
      expect(tester.takeException(), isNull);

      // The route a go built has no caller: finishing it adds nothing.
      await tester.tap(find.byKey(_finish));
      await tester.pumpAndSettle();
      expect(app.got, [null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0054-AC1 a guard redirect, then the user goes Back: null '
        'once', (tester) async {
      final app = await _app(tester, signedIn: false);
      await app.open(tester);

      app.router.pop();
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      expect(find.byKey(_home), findsOneWidget);
    });

    testWidgets('T-0054-AC1 a guard redirect, then go home: null once', (
      tester,
    ) async {
      final app = await _app(tester, signedIn: false);
      await app.open(tester);

      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
    });

    testWidgets('T-0054-AC1 a redirected page that pops with a value gives '
        'the caller that value (the push future is chained)', (tester) async {
      final app = await _app(tester, signedIn: false);
      await app.open(tester);

      await tester.tap(find.byKey(_signInPop));
      await tester.pumpAndSettle();

      expect(app.got, ['signed']);
    });

    testWidgets('T-0054-AC1 the call is keyed by the call, not the location: '
        'two callers of one location complete one by one', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      await app.open(tester);

      await tester.tap(find.byKey(_finish));
      await tester.pumpAndSettle();
      expect(app.got, ['l-5'], reason: 'the top route answers its own caller');

      app.router.pop();
      await tester.pumpAndSettle();
      expect(app.got, ['l-5', null]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0054-AC1 a go to the pushed location is not a forgotten '
        'extra, a route that really forgot it still asserts', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      app.router.go(AppLocations.newReadingList);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final forgetful = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, s) => const Text('home')),
          GoRoute(
            path: AppLocations.newReadingList,
            builder: (context, s) => FlowResultRoute<String>(
              builder: (complete) => _FakeFlow(onComplete: complete),
            ),
          ),
        ],
      );
      addTearDown(forgetful.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: forgetful));
      await tester.pumpAndSettle();
      unawaited(AppFlows.createReadingList(forgetful));
      await tester.pumpAndSettle();

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('extra: state.extra'));
    });
  });

  group('T-0054-AC1 review: re-parses, same-frame replacement, listeners', () {
    var changes = 0;
    setUp(() {
      changes = 0;
      AppFlows.debugOnChange = () => changes++;
      addTearDown(() => AppFlows.debugOnChange = null);
    });

    /// After every call ended, router changes reach no watch any more: no
    /// listener of a call is left on the delegate.
    Future<void> expectNoListenerLeft(WidgetTester tester, _App app) async {
      final before = changes;
      app.router.go('/signin?from=%2F');
      await tester.pumpAndSettle();
      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();
      expect(changes, before, reason: 'a call still listens');
    }

    testWidgets('T-0054-AC1 router.refresh() during a flow, then save: the '
        'result, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);

      app.router.refresh();
      await tester.pumpAndSettle();
      expect(app.got, isEmpty, reason: 'the page is still there');
      await tester.tap(find.byKey(_finish));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
      expect(tester.takeException(), isNull);
      await expectNoListenerLeft(tester, app);
    });

    testWidgets('T-0054-AC1 router.refresh() then Back: null, once', (
      tester,
    ) async {
      final app = await _app(tester);
      await app.open(tester);

      app.router.refresh();
      await tester.pumpAndSettle();
      app.router.pop();
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      await expectNoListenerLeft(tester, app);
    });

    testWidgets('T-0054-AC1 a refreshListenable tick during a flow, then '
        'save: the result, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);

      app.tick.value++;
      await tester.pumpAndSettle();
      app.tick.value++;
      await tester.pumpAndSettle();
      expect(app.got, isEmpty);
      await tester.tap(find.byKey(_finish));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
      await expectNoListenerLeft(tester, app);
    });

    testWidgets('T-0054-AC1 a refresh, then a go elsewhere: null, once', (
      tester,
    ) async {
      final app = await _app(tester);
      await app.open(tester);

      app.router.refresh();
      await tester.pumpAndSettle();
      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      await expectNoListenerLeft(tester, app);
    });

    testWidgets('T-0054-AC1 a restore of the saved route state during a flow, '
        'then save: the result, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      final saved = app.router.routeInformationParser.restoreRouteInformation(
        app.router.routerDelegate.currentConfiguration,
      )!;

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {
            'location': saved.uri.toString(),
            'state': saved.state,
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(app.got, isEmpty, reason: 'the page is still there');
      await tester.tap(find.byKey(_finish));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
      await expectNoListenerLeft(tester, app);
    });

    testWidgets('T-0054-AC1 a go in the same synchronous span as the push: '
        'null, once, and nothing is left listening', (tester) async {
      final app = await _app(tester);
      unawaited(AppFlows.createReadingList(app.router).then(app.got.add));
      app.router.go(AppLocations.characters);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      await expectNoListenerLeft(tester, app);
      expect(find.byKey(_finish), findsNothing);
    });

    testWidgets('T-0054-AC1 a go to the pushed location in the same span: '
        'null, once', (tester) async {
      final app = await _app(tester);

      unawaited(AppFlows.createReadingList(app.router).then(app.got.add));
      app.router.go(AppLocations.newReadingList);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      await expectNoListenerLeft(tester, app);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0054-AC1 a redirected page that pops true (the sign-in '
        'sheet does): null, nothing throws', (tester) async {
      final app = await _app(tester, signedIn: false);
      await app.open(tester);

      await tester.tap(find.byKey(_signInPopTrue));
      await tester.pumpAndSettle();

      expect(app.got, [null]);
      expect(tester.takeException(), isNull);
      await expectNoListenerLeft(tester, app);
    });

    testWidgets('T-0054-AC1 every end removes the listener', (tester) async {
      final app = await _app(tester, signedIn: false);
      await app.open(tester);

      app.router.pop();
      await tester.pumpAndSettle();
      await expectNoListenerLeft(tester, app);

      await app.open(tester);
      await tester.tap(find.byKey(_signIn));
      await tester.pumpAndSettle();
      await expectNoListenerLeft(tester, app);
    });
  });

  group('T-0057-AC1 the async-guard paths (P-110)', () {
    var changes = 0;
    setUp(() {
      changes = 0;
      AppFlows.debugOnChange = () => changes++;
      addTearDown(() => AppFlows.debugOnChange = null);
    });

    Future<void> expectNoListenerLeft(WidgetTester tester, _App app) async {
      final before = changes;
      app.router.go('/other');
      await tester.pumpAndSettle();
      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();
      expect(changes, before, reason: 'a call still listens');
    }

    // VP07b (T-0054 Verifier). Kills X02 (a push not yet located always
    // counts as superseded).
    testWidgets('T-0057-AC1 a slow async guard (spans frames): the push is '
        'not abandoned while it is still being redirected, then go(from) '
        'gives null once', (tester) async {
      final app = await _app(
        tester,
        signedIn: false,
        guardDelay: const Duration(milliseconds: 400),
      );
      app.create();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.tagged, isEmpty, reason: 'a push still in its redirect lives');

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(_signIn), findsOneWidget);
      expect(app.tagged, isEmpty);

      await tester.tap(find.byKey(_signIn));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(app.tagged, ['c:null']);
      await expectNoListenerLeft(tester, app);
      expect(app.tagged, ['c:null']);
    });

    // VP16. Kills X03 (never superseded).
    testWidgets('T-0057-AC1 an async guard and a go in the same span: the '
        'push is superseded before it showed, null once', (tester) async {
      final app = await _app(
        tester,
        signedIn: false,
        guardDelay: const Duration(milliseconds: 50),
      );
      app.create();
      app.router.go('/other');
      await tester.pumpAndSettle();

      expect(app.tagged, ['c:null']);
      expect(find.byKey(_signIn), findsNothing);
      await expectNoListenerLeft(tester, app);
      expect(app.tagged, ['c:null']);
    });

    // VP23. Kills X06 (first match by any imperative page).
    for (final how in ['replace', 'pushReplacement']) {
      testWidgets('T-0057-AC1 two calls, the second redirected, then $how of '
          'the sign-in page: each call ends once', (tester) async {
        final app = await _app(tester);
        app.create();
        await tester.pumpAndSettle();
        app.signedIn.value = false;
        await tester.pumpAndSettle();
        app.edit('l-4');
        await tester.pumpAndSettle();
        expect(find.byKey(_signIn), findsOneWidget);

        if (how == 'replace') {
          unawaited(app.router.replace<void>('/other'));
        } else {
          unawaited(app.router.pushReplacement<void>('/other'));
        }
        await tester.pumpAndSettle();
        expect(find.text('other'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(app.tagged, contains('e:null'), reason: 'the redirected call');
        expect(
          app.tagged.where((g) => g.startsWith('c:')),
          isEmpty,
          reason: 'the editor below is still open',
        );
        expect(find.byKey(_finish), findsOneWidget);

        await tester.tap(find.byKey(_finish));
        await tester.pumpAndSettle();
        expect(app.tagged, ['e:null', 'c:l-5']);
        await expectNoListenerLeft(tester, app);
        expect(app.tagged, ['e:null', 'c:l-5']);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('T-0054-AC3 a result held under an overlay is delivered', () {
    testWidgets('T-0054-AC3 complete, then a go before the dialog closes: the '
        'result, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      _dialog(tester);
      await tester.pumpAndSettle();

      tester.widget<TextButton>(find.byKey(_finish)).onPressed!();
      await tester.pumpAndSettle();
      expect(app.got, isEmpty, reason: 'held under the dialog');
      app.router.go(AppLocations.editReadingList('l-3'));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T-0054-AC3 the dialog closes, then a go: the result, once', (
      tester,
    ) async {
      final app = await _app(tester);
      await app.open(tester);
      final navigator = _dialog(tester);
      await tester.pumpAndSettle();
      tester.widget<TextButton>(find.byKey(_finish)).onPressed!();
      await tester.pumpAndSettle();

      navigator.pop();
      await tester.pumpAndSettle();
      app.router.go(AppLocations.editReadingList('l-3'));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
    });

    testWidgets('T-0054-AC3 the dialog closes and a go follows in the same '
        'frame: the result, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      final navigator = _dialog(tester);
      await tester.pumpAndSettle();
      tester.widget<TextButton>(find.byKey(_finish)).onPressed!();
      await tester.pumpAndSettle();

      navigator.pop();
      app.router.go(AppLocations.editReadingList('l-3'));
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
    });

    testWidgets('T-0054-AC3 a go, then the dialog closes in the same frame: '
        'the result, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      final navigator = _dialog(tester);
      await tester.pumpAndSettle();
      tester.widget<TextButton>(find.byKey(_finish)).onPressed!();
      await tester.pumpAndSettle();

      app.router.go(AppLocations.editReadingList('l-3'));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(app.got, ['l-5']);
    });

    testWidgets('T-0054-AC3 a route removed while it holds a result under a '
        'dialog hands it over (no router involved)', (tester) async {
      final call = FlowCall<String>();
      await tester.pumpWidget(const MaterialApp(home: Text('home')));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final route = MaterialPageRoute<String>(
        builder: (_) => FlowResultRoute<String>(
          extra: call,
          builder: (complete) => _FakeFlow(onComplete: complete),
        ),
      );
      unawaited(navigator.push<String>(route));
      await tester.pumpAndSettle();
      _dialog(tester);
      await tester.pumpAndSettle();
      tester.widget<TextButton>(find.byKey(_finish)).onPressed!();
      await tester.pumpAndSettle();
      expect(call.isCompleted, isFalse, reason: 'held under the dialog');

      navigator.removeRoute(route);
      await tester.pumpAndSettle();

      expect(await call.result, 'l-5');
    });

    testWidgets('T-0054-AC3 an empty result held under a dialog, then a go: '
        'null, once', (tester) async {
      final app = await _app(tester);
      await app.open(tester);
      _dialog(tester);
      await tester.pumpAndSettle();
      tester.widget<TextButton>(find.byKey(_finishEmpty)).onPressed!();
      await tester.pumpAndSettle();

      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
    });

    testWidgets('T-0054-AC3 no result held, a dialog and a go: null, once', (
      tester,
    ) async {
      final app = await _app(tester);
      await app.open(tester);
      _dialog(tester);
      await tester.pumpAndSettle();

      app.router.go(AppLocations.home);
      await tester.pumpAndSettle();

      expect(app.got, [null]);
    });
  });

  group('T-0054-AC2 FlowExtraCodec', () {
    setUp(resetFlowExtraWarnings);

    final lines = <String>[];
    late DebugPrintCallback previous;
    setUp(() {
      lines.clear();
      previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      // addTearDown: it runs before the binding checks its debug variables.
      addTearDown(() => debugPrint = previous);
      // go_router logs through package:logging (with debugLogDiagnostics).
      final logs = go_router_log.logger.onRecord.listen(
        (record) => lines.add('go_router: ${record.message}'),
      );
      addTearDown(logs.cancel);
    });

    test('T-0054-AC2 JSON-safe extras round-trip through JSON', () {
      const codec = FlowExtraCodec();
      final values = <Object?>[
        null,
        true,
        3,
        2.5,
        'text',
        <Object?>[1, 'a', null, <Object?>[]],
        <String, Object?>{
          'id': 7,
          'tags': <Object?>['x', 'y'],
          'nested': <String, Object?>{'ok': true},
        },
      ];
      for (final value in values) {
        final saved = jsonDecode(jsonEncode(codec.encode(value)));
        expect(codec.decode(saved), value, reason: '$value');
      }
      expect(lines, isEmpty);
    });

    test('T-0054-AC2 a FlowCall is dropped, never saved', () {
      const codec = FlowExtraCodec();

      expect(codec.encode(FlowCall<String>()), isNull);
      expect(codec.decode(FlowCall<String>()), isNull);
      // Inside a value it makes the whole value unsafe: dropped, and warned.
      expect(codec.encode(<String, Object?>{'c': FlowCall<String>()}), isNull);
      expect(lines, hasLength(1));
    });

    test('T-0054-AC2 values JSON would refuse are dropped with one warning '
        'naming the type', () {
      const codec = FlowExtraCodec();
      final unsafe = <Object?>[
        _Picker(3),
        <int, String>{1: 'a'},
        <Object?>[_Picker(1)],
        double.nan,
        double.infinity,
        () {},
      ];

      for (final value in unsafe) {
        expect(codec.encode(value), isNull, reason: '$value');
        expect(codec.decode(value), isNull, reason: '$value');
      }

      expect(lines.where((l) => l.contains('_Picker')), hasLength(1));
    });

    test('T-0054-AC2 a self-referencing value is dropped, not recursed '
        'into', () {
      const codec = FlowExtraCodec();
      final loop = <Object?>[];
      loop.add(loop);

      expect(codec.encode(loop), isNull);
    });

    testWidgets('T-0054-AC2 a custom extra, pushed and reported, does not '
        'throw: it decodes as null and logs one warning', (tester) async {
      final seen = <Object?>[];
      final router = GoRouter(
        debugLogDiagnostics: true,
        extraCodec: const FlowExtraCodec(),
        routes: [
          GoRoute(path: '/', builder: (context, s) => const Text('home')),
          GoRoute(
            path: '/picker',
            builder: (context, s) {
              seen.add(s.extra);
              return const Text('picker');
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(router.push<void>('/picker', extra: _Picker(3)));
      await tester.pumpAndSettle();
      final first = router.routeInformationParser.restoreRouteInformation(
        router.routerDelegate.currentConfiguration,
      )!;
      router.routeInformationParser.restoreRouteInformation(
        router.routerDelegate.currentConfiguration,
      );

      // Back to the real one before the binding checks it (testWidgets runs
      // tear-downs after that check).
      debugPrint = previous;
      expect(tester.takeException(), isNull);
      // The saved state is JSON, with no trace of the extra.
      final encoded = jsonEncode(first.state);
      expect(encoded, isNot(contains('Picker')));
      expect(encoded, isNot(contains('FlowCall')));
      // Live, the route got its extra; saved and restored, it is null.
      expect(seen.first, isA<_Picker>());
      const codec = FlowExtraCodec();
      expect(codec.decode(codec.encode(seen.first)), isNull);
      // One warning from the codec, none about the extra from go_router.
      expect(lines.where((l) => l.contains('FlowExtraCodec')), hasLength(1));
      expect(lines.where((l) => l.contains('_Picker')), hasLength(1));
      expect(lines.where((l) => l.contains('complex data type')), isEmpty);
      expect(
        lines.where((l) => l.contains('pushing /picker')),
        isNotEmpty,
        reason: "go_router's own log is captured",
      );
    });

    testWidgets('T-0054-AC2 a FlowCall push is saved with no trace of the '
        'call', (tester) async {
      final router = GoRouter(
        extraCodec: const FlowExtraCodec(),
        routes: [
          GoRoute(path: '/', builder: (context, s) => const Text('home')),
          GoRoute(
            path: AppLocations.newReadingList,
            builder: (context, s) => FlowResultRoute<String>(
              extra: s.extra,
              builder: (complete) => _FakeFlow(onComplete: complete),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      unawaited(AppFlows.createReadingList(router));
      await tester.pumpAndSettle();
      final saved = router.routeInformationParser.restoreRouteInformation(
        router.routerDelegate.currentConfiguration,
      )!;

      debugPrint = previous;
      expect(jsonEncode(saved.state), isNot(contains('FlowCall')));
      expect(lines.where((l) => l.contains('FlowExtraCodec')), isEmpty);
    });
  });
}

class _Picker {
  _Picker(this.count);

  final int count;
}
