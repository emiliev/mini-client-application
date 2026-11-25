import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

class _Counter extends Cubit<int> {
  _Counter() : super(0) {
    created++;
  }

  static int created = 0;
}

class _Provided {
  const _Provided(this.label);
  final String label;
}

class _State {
  const _State([this.selected]);
  final String? selected;
}

class _Strings {
  const _Strings(this.hello);

  static _Strings of(BuildContext context) =>
      Localizations.of<_Strings>(context, _Strings)!;

  final String hello;
}

class _StringsDelegate extends LocalizationsDelegate<_Strings> {
  const _StringsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'de'].contains(locale.languageCode);

  @override
  Future<_Strings> load(Locale locale) async =>
      _Strings(locale.languageCode == 'de' ? 'Hallo' : 'Hello');

  @override
  bool shouldReload(_StringsDelegate old) => false;
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('de')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: home),
);

McDIInitializer _counterInitializer() => McDIInitializer(
  (getIt, _) => getIt.registerFactory<_Counter>(_Counter.new),
);

/// A page that creates its bloc from the flow, as plan 01 §3.3 writes it.
class _CounterPage extends StatelessWidget {
  const _CounterPage();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.di<_Counter>(),
    child: const Text('counter page'),
  );
}

/// Counts its builds; [listen] picks the listening lookup (a control).
class _Dependent extends StatelessWidget {
  const _Dependent({required this.listen, required this.onBuild});

  final bool listen;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    if (listen) {
      FlowScope.of(context);
    } else {
      context.di<_Counter>();
    }
    return const SizedBox();
  }
}

void main() {
  setUp(() async {
    await resetDIContainer();
    await initializeDIContainer(const []);
    _Counter.created = 0;
  });

  tearDown(resetDIContainer);

  testWidgets('T-0034-AC1 context.di inside BlocProvider.create does not '
      'throw and creates the bloc once', (tester) async {
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State(),
          flowInitializer: _counterInitializer(),
          onGeneratePages: (_) => const [
            McFlowPage(name: 'list', child: _CounterPage()),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('counter page'), findsOneWidget);
    expect(_Counter.created, 1);

    // Unmounting disposes the provider without the lifecycle assertion.
    await tester.pumpWidget(_app(const SizedBox()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('T-0034-AC1 context.di registers no dependency on the scope and '
      'a new scope does not recreate the bloc', (tester) async {
    final first = (await tester.runAsync(
      () => createChildContainer(initializers: [_counterInitializer()]),
    ))!;
    final second = (await tester.runAsync(
      () => createChildContainer(initializers: [_counterInitializer()]),
    ))!;
    var plainBuilds = 0;
    var listeningBuilds = 0;
    Widget host(ChildDIContainer container) => _app(
      FlowScope(
        container: container,
        child: Column(
          children: [
            const _CounterPage(),
            _Dependent(listen: false, onBuild: () => plainBuilds++),
            _Dependent(listen: true, onBuild: () => listeningBuilds++),
          ],
        ),
      ),
    );

    await tester.pumpWidget(host(first));
    expect((plainBuilds, listeningBuilds), (1, 1));
    final createdBefore = _Counter.created;

    await tester.pumpWidget(host(second));

    // The control: a listening lookup is rebuilt when the scope changes, so
    // the scope did notify. The non-listening one is not.
    expect(listeningBuilds, 2, reason: 'control: the scope notified');
    expect(plainBuilds, 1, reason: 'context.di registered no dependency');
    expect(_Counter.created, createdBefore, reason: 'the bloc is kept');
    expect(tester.takeException(), isNull);
  });

  testWidgets('T-0034-AC2 provide: resolves inside the flow and nowhere '
      'outside it', (tester) async {
    String? inside;
    Object? otherFlow;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            FeatureFlow<_State>(
              state: const _State(),
              provide: (scope) =>
                  scope.registerSingleton<_Provided>(const _Provided('nav')),
              onGeneratePages: (_) => [
                McFlowPage(
                  name: 'list',
                  child: Builder(
                    builder: (context) {
                      inside = context.di<_Provided>().label;
                      return const Text('inside');
                    },
                  ),
                ),
              ],
            ),
            FeatureFlow<_State>(
              state: const _State(),
              onGeneratePages: (_) => [
                McFlowPage(
                  name: 'list',
                  child: Builder(
                    builder: (context) {
                      try {
                        context.di<_Provided>();
                      } on Object catch (error) {
                        otherFlow = error;
                      }
                      return const Text('other');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(inside, 'nav');
    expect(otherFlow, isNotNull, reason: 'a flow without provide: has none');
    expect(diContainer.isRegistered<_Provided>(), isFalse);
  });

  testWidgets('T-0034-AC2 localizationsDelegates resolve the flow strings in '
      'en and de', (tester) async {
    Future<void> pumpIn(Locale locale) async {
      await tester.pumpWidget(
        _app(
          locale: locale,
          FeatureFlow<_State>(
            state: const _State(),
            localizationsDelegates: const [_StringsDelegate()],
            onGeneratePages: (_) => [
              McFlowPage(
                name: 'list',
                child: Builder(
                  builder: (context) => Text(
                    '${_Strings.of(context).hello} / '
                    '${McL10nCoreL10n.of(context).commonRetry}',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpIn(const Locale('en'));
    expect(find.text('Hello / Retry'), findsOneWidget);
    await pumpIn(const Locale('de'));
    expect(find.textContaining('Hallo / '), findsOneWidget);
    expect(find.text('Hello / Retry'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T-0034-AC2 without localizationsDelegates the host decides', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State(),
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'list',
              child: Builder(
                builder: (context) =>
                    Text('${Localizations.of<_Strings>(context, _Strings)}'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('null'), findsOneWidget);
  });

  testWidgets('T-0034-AC6 flowStateOf reads the flow state through the '
      'controller', (tester) async {
    late FeatureFlowController<_State> controller;
    late BuildContext page;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State(),
          onGeneratePages: (s) => [
            McFlowPage(
              name: 'list',
              child: Builder(
                builder: (context) {
                  page = context;
                  controller = context.di<FeatureFlowController<_State>>();
                  return const Text('list');
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(flowStateOf<_State>(page).selected, isNull);
    controller.update((_) => const _State('x'));
    await tester.pump();
    expect(flowStateOf<_State>(page).selected, 'x');
    // A feature keeps its state type private: tests ask for `dynamic` and get
    // the same instance.
    expect(flowStateOf<dynamic>(page), same(flowStateOf<_State>(page)));
  });

  testWidgets('T-0034-AC6 flowStateOf fails on another state type and outside '
      'a flow', (tester) async {
    late BuildContext page;
    late BuildContext outside;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Builder(
              builder: (context) {
                outside = context;
                return const SizedBox();
              },
            ),
            FeatureFlow<_State>(
              state: const _State(),
              onGeneratePages: (_) => [
                McFlowPage(
                  name: 'list',
                  child: Builder(
                    builder: (context) {
                      page = context;
                      return const Text('list');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      () => flowStateOf<String>(page),
      throwsA(
        isA<StateError>().having(
          (e) => '$e',
          'message',
          allOf(contains('_State'), contains('String')),
        ),
      ),
    );
    expect(() => flowStateOf<_State>(outside), throwsFlutterError);
  });
}
