import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_monitoring/mc_monitoring.dart';

class _Selection {
  const _Selection([this.selected]);
  final String? selected;
}

class _Dep {}

class _NeedsDep {
  _NeedsDep(this.dep);
  final _Dep dep;
}

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.iOS}) =>
    MaterialApp(
      theme: McTheme.light.copyWith(platform: platform),
      home: Scaffold(body: child),
    );

List<McFlowPage> _pages(_Selection s) => [
  const McFlowPage(name: 'list', child: Text('list page')),
  if (s.selected != null)
    McFlowPage(name: 'detail', child: Text('detail ${s.selected}')),
];

/// Exposes the flow's controller so tests can drive the flow.
class _Probe extends StatelessWidget {
  const _Probe({required this.onController});

  final void Function(FeatureFlowController<_Selection>) onController;

  @override
  Widget build(BuildContext context) {
    onController(context.di<FeatureFlowController<_Selection>>());
    return const Text('probe');
  }
}

void main() {
  late InMemorySink sink;

  setUp(() async {
    await resetDIContainer();
    sink = InMemorySink();
    await initializeDIContainer([
      MonitoringDIInitializer(sinks: [sink]),
    ]);
  });

  tearDown(resetDIContainer);

  testWidgets('T-0022-AC1 no flowInitializer renders the first page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FeatureFlow<_Selection>(
          state: _Selection(),
          onGeneratePages: _pages,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('list page'), findsOneWidget);
    expect(find.text('detail x'), findsNothing);
  });

  testWidgets('T-0022-AC2 a throwing initializer shows Retry and records', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_Selection>(
          state: const _Selection(),
          onGeneratePages: _pages,
          flowInitializer: McDIInitializer((getIt, _) {
            attempts++;
            if (attempts == 1) {
              throw StateError('init failed');
            }
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('init failed'), findsOneWidget);
    expect(sink.entries.whereType<ErrorEntry>(), hasLength(1));

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('list page'), findsOneWidget);
  });

  testWidgets('T-0022-AC3 complete(r) calls onComplete once with r', (
    tester,
  ) async {
    final results = <Object?>[];
    late FeatureFlowController<_Selection> controller;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_Selection>(
          state: const _Selection(),
          onComplete: results.add,
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'only',
              child: _Probe(onController: (c) => controller = c),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller
      ..complete('done')
      ..complete('again');
    await tester.pump();
    expect(results, ['done']);
  });

  testWidgets('T-0022-AC4 two flows in an IndexedStack own their controllers', (
    tester,
  ) async {
    final controllers = <String, FeatureFlowController<_Selection>>{};
    Widget flow(String id) => FeatureFlow<_Selection>(
      state: _Selection(id),
      onGeneratePages: (_) => [
        McFlowPage(
          name: id,
          child: _Probe(onController: (c) => controllers[id] = c),
        ),
      ],
    );
    await tester.pumpWidget(
      _app(IndexedStack(children: [flow('a'), flow('b')])),
    );
    await tester.pumpAndSettle();
    expect(controllers.keys, containsAll(['a', 'b']));
    expect(controllers['a'], isNot(same(controllers['b'])));
    expect(controllers['a']!.state.selected, 'a');
    expect(controllers['b']!.state.selected, 'b');
  });

  testWidgets('T-0022-AC5 iOS edge swipe pops a named page and reverts state', (
    tester,
  ) async {
    late FeatureFlowController<_Selection> controller;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_Selection>(
          state: const _Selection(),
          onGeneratePages: (s) => [
            McFlowPage(
              name: 'list',
              child: _Probe(onController: (c) => controller = c),
            ),
            if (s.selected != null)
              McFlowPage(name: 'detail', child: Text('detail ${s.selected}')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.update((_) => const _Selection('x'));
    await tester.pumpAndSettle();
    expect(find.text('detail x'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.text('detail x')))!.settings.name,
      'detail',
    );

    // Edge swipe from the left, not Navigator.pop.
    final gesture = await tester.startGesture(const Offset(2, 300));
    await gesture.moveBy(const Offset(400, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('detail x'), findsNothing);
    expect(find.text('probe'), findsOneWidget);
    expect(controller.state.selected, isNull);
  });

  testWidgets('T-0022-AC6 an unregistered root import fails naming its type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FeatureFlow<_Selection>(
          state: _Selection(),
          rootImports: [RootImport<_Dep>()],
          onGeneratePages: _pages,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final error = tester.takeException();
    expect(error, isA<StateError>());
    expect('$error', contains('_Dep'));
  });

  testWidgets('T-0022-AC6 debugResolveAll names both types', (tester) async {
    await resetDIContainer();
    await initializeDIContainer([
      McDIInitializer((getIt, _) => getIt.registerSingleton<_Dep>(_Dep())),
    ]);
    late BuildContext flowContext;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_Selection>(
          state: const _Selection(),
          rootImports: const [RootImport<_Dep>()],
          flowInitializer: McDIInitializer((getIt, _) {
            // _NeedsDep is registered, but the dependency it asks for is
            // not: _Selection.
            getIt.registerFactory<_NeedsDep>(() => _NeedsDep(getIt<_Dep>()));
            getIt.registerFactory<_Other>(() => _Other(getIt<_Missing>()));
          }),
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'only',
              child: Builder(
                builder: (context) {
                  flowContext = context;
                  return const Text('ok');
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      flowContext.debugResolveAll(),
      throwsA(
        isA<StateError>().having(
          (e) => '$e',
          'message',
          allOf(contains('_Other'), contains('_Missing')),
        ),
      ),
    );
  });
}

class _Missing {}

class _Other {
  _Other(this.missing);
  final _Missing missing;
}
