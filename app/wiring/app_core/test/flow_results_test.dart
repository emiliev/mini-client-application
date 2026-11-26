// T-0048: the app layer's half of the flow-result pattern (plan 01 §4.3):
// a route built in a FlowResultRoute pops itself with the flow's result, so
// the caller's push completes with it.
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _finish = Key('finish');
const _finishEmpty = Key('finish.empty');

/// Stands in for a feature flow that ends with a result.
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

Future<GoRouter> _app(WidgetTester tester, {String initial = '/'}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Text('home', key: Key('home')),
      ),
      GoRoute(
        path: AppLocations.newReadingList,
        builder: (context, state) => FlowResultRoute<String>(
          builder: (complete) => _FakeFlow(onComplete: complete),
        ),
      ),
      GoRoute(
        path: '/me/lists/:id/edit',
        builder: (context, state) => FlowResultRoute<String>(
          builder: (complete) => _FakeFlow(
            onComplete: (_) => complete(state.pathParameters['id']),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('T-0048-AC6 the caller awaits AppFlows.createReadingList and '
      'gets the result the flow completed with', (tester) async {
    final router = await _app(tester);

    final result = AppFlows.createReadingList(router);
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/me/lists/new');
    await tester.tap(find.byKey(_finish));
    await tester.pumpAndSettle();

    expect(await result, 'l-5');
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  testWidgets('T-0048-AC6 AppFlows.editReadingList pushes the edit location '
      'and completes with the id', (tester) async {
    final router = await _app(tester);

    final result = AppFlows.editReadingList(router, 'l-1');
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), AppLocations.editReadingList('l-1'));
    await tester.tap(find.byKey(_finish));
    await tester.pumpAndSettle();

    expect(await result, 'l-1');
  });

  testWidgets('T-0048-AC6 a flow that ends without a result, and Back, give '
      'the caller null', (tester) async {
    final router = await _app(tester);

    final empty = AppFlows.createReadingList(router);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_finishEmpty));
    await tester.pumpAndSettle();
    expect(await empty, isNull);

    final back = AppFlows.createReadingList(router);
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(await back, isNull);
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  testWidgets('T-0048-AC6 a result that arrives under a dialog is kept, '
      'and the caller gets it once the dialog closed', (tester) async {
    final router = await _app(tester);
    String? got;
    var done = false;
    final result = AppFlows.createReadingList(router).then((value) {
      got = value;
      done = true;
    });
    await tester.pumpAndSettle();
    final finish = tester.widget<TextButton>(find.byKey(_finish));
    unawaited(
      showDialog<void>(
        context: tester.element(find.byKey(_finish)),
        builder: (_) => const Text('dialog', key: Key('dialog')),
      ),
    );
    await tester.pumpAndSettle();

    finish.onPressed!();
    await tester.pumpAndSettle();

    // Nothing above the route is popped for the result.
    expect(find.byKey(const Key('dialog')), findsOneWidget);
    expect(router.state.uri.toString(), '/me/lists/new');
    expect(done, isFalse);
    // A second completion while it waits is ignored.
    tester
        .widget<TextButton>(find.byKey(_finishEmpty, skipOffstage: false))
        .onPressed!();

    Navigator.of(tester.element(find.byKey(const Key('dialog')))).pop();
    await tester.pumpAndSettle();
    await result;

    expect(got, 'l-5');
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  testWidgets('T-0048-AC6 a route opened by a deep link (nothing below it) '
      'goes home when it completes', (tester) async {
    final router = await _app(tester, initial: AppLocations.newReadingList);
    expect(find.byKey(const Key('home')), findsNothing);

    await tester.tap(find.byKey(_finish));
    await tester.pumpAndSettle();

    expect(router.state.uri.toString(), AppLocations.home);
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  testWidgets('T-0048-AC6 completing after the route left the tree does '
      'nothing', (tester) async {
    final router = await _app(tester);
    unawaited(AppFlows.createReadingList(router));
    await tester.pumpAndSettle();
    final finish = tester.widget<TextButton>(find.byKey(_finish));
    router.pop();
    await tester.pumpAndSettle();

    finish.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T-0048-AC6 a second completion pops nothing more', (
    tester,
  ) async {
    final router = await _app(tester);
    unawaited(router.push<void>('/me/lists/l-9/edit'));
    await tester.pumpAndSettle();
    final result = AppFlows.createReadingList(router);
    await tester.pumpAndSettle();
    final finish = tester.widget<TextButton>(find.byKey(_finish));

    finish.onPressed!();
    finish.onPressed!();
    await tester.pumpAndSettle();

    expect(await result, 'l-5');
    expect(router.state.uri.toString(), '/me/lists/l-9/edit');
  });

  test('T-0048-AC5 the reading-list locations', () {
    expect(AppLocations.newReadingList, '/me/lists/new');
    expect(AppLocations.editReadingList('l-1'), '/me/lists/l-1/edit');
    expect(AppLocations.editReadingList('a b'), '/me/lists/a%20b/edit');
  });
}
