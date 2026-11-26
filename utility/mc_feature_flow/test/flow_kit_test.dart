import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
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
  theme: McTheme.light,
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('de')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: home),
);

/// Gives a flow a bounded slot, so two of them fit one column.
class _Slot extends StatelessWidget {
  const _Slot(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(height: 100, child: child);
}

McDIInitializer _counterInitializer() => McDIInitializer(
  (getIt, _) => getIt.registerFactory<_Counter>(_Counter.new),
);

/// A page that creates its bloc from the flow, as plan 01 §3.3 writes it.
class _CounterPage extends StatelessWidget {
  const _CounterPage();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => context.di<_Counter>(),
    child: Builder(
      builder: (context) =>
          Text('counter page ${context.read<_Counter>().state}'),
    ),
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
    expect(find.text('counter page 0'), findsOneWidget);
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
    // One widget instance below the scope: only a dependency on the scope
    // rebuilds it, never its parent.
    final page = Column(
      children: [
        const _CounterPage(),
        _Dependent(listen: false, onBuild: () => plainBuilds++),
        _Dependent(listen: true, onBuild: () => listeningBuilds++),
      ],
    );
    Widget host(ChildDIContainer container) =>
        _app(FlowScope(container: container, child: page));

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
            _Slot(
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
            ),
            _Slot(
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
    expect(find.text('Hallo / Erneut versuchen'), findsOneWidget);
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
            _Slot(
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

  testWidgets('T-0034-AC2 provide: is registered before flowInitializer runs', (
    tester,
  ) async {
    Object? seen;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State(),
          provide: (scope) =>
              scope.registerSingleton<_Provided>(const _Provided('first')),
          flowInitializer: McDIInitializer((getIt, _) {
            // Throws when `provide:` has not run yet.
            seen = getIt<_Provided>().label;
          }),
          onGeneratePages: (_) => const [
            McFlowPage(name: 'list', child: Text('list page')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(seen, 'first');
    expect(find.text('list page'), findsOneWidget);
  });

  testWidgets('T-0034-AC2 a host MaterialLocalizations override survives '
      'inside the flow, and the flow still adds its own strings', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: McTheme.light,
        localizationsDelegates: [
          const _CustomMaterialDelegate(),
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: FeatureFlow<_State>(
            state: const _State(),
            localizationsDelegates: const [_StringsDelegate()],
            onGeneratePages: (_) => [
              McFlowPage(
                name: 'list',
                child: Builder(
                  builder: (context) => Text(
                    '${MaterialLocalizations.of(context).okButtonLabel} / '
                    '${_Strings.of(context).hello}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CUSTOM-OK / Hello'), findsOneWidget);
  });

  testWidgets('T-0034-AC2 a host without core or Flutter delegates gets them '
      'from the flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: McTheme.light,
        home: Scaffold(
          body: FeatureFlow<_State>(
            state: const _State(),
            onGeneratePages: (_) => [
              McFlowPage(
                name: 'list',
                child: Builder(
                  builder: (context) =>
                      Text(McL10nCoreL10n.of(context).commonRetry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('T-0034-AC2 changing localizationsDelegates keeps the pushed '
      'page and its state', (tester) async {
    late FeatureFlowController<_State> controller;
    final delegates = ValueNotifier<List<LocalizationsDelegate<Object?>>>(
      const [],
    );
    addTearDown(delegates.dispose);
    _Probe.inits = 0;
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder(
          valueListenable: delegates,
          builder: (context, value, _) => FeatureFlow<_State>(
            state: const _State(),
            localizationsDelegates: value,
            onGeneratePages: (s) => [
              McFlowPage(
                name: 'list',
                child: Builder(
                  builder: (context) {
                    controller = context.di<FeatureFlowController<_State>>();
                    return const Text('list');
                  },
                ),
              ),
              if (s.selected != null)
                const McFlowPage(name: 'detail', child: _Probe()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.update((_) => const _State('x'));
    await tester.pumpAndSettle();
    expect(_Probe.inits, 1);

    delegates.value = const [_StringsDelegate()];
    await tester.pumpAndSettle();
    delegates.value = const [];
    await tester.pumpAndSettle();

    expect(find.text('detail probe'), findsOneWidget);
    expect(_Probe.inits, 1, reason: 'the page was not remounted');
    expect(controller.state.selected, 'x');
  });

  group('T-0036-AC2 the flow root page can leave the flow', () {
    Widget flowWithAppBar() => FeatureFlow<_State>(
      state: const _State(),
      onGeneratePages: (s) => [
        McFlowPage(
          name: 'list',
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                leading: const McFlowBackButton(),
                title: const Text('flow root'),
              ),
            ),
          ),
        ),
      ],
    );

    Widget app(Widget home) => MaterialApp(
      theme: McTheme.light,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );

    testWidgets('T-0036-AC2 present when pushed, and tapping it pops the '
        'flow', (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => flowWithAppBar()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('flow root'), findsOneWidget);

      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('flow root'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('T-0036-AC2 absent when the flow is the root', (tester) async {
      await tester.pumpWidget(app(flowWithAppBar()));
      await tester.pumpAndSettle();

      expect(find.text('flow root'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('T-0036-AC2 a page pushed inside the flow keeps the automatic '
        'back button, which pops that page only', (tester) async {
      late FeatureFlowController<_State> controller;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => FeatureFlow<_State>(
                      state: const _State(),
                      onGeneratePages: (s) => [
                        McFlowPage(
                          name: 'list',
                          child: Builder(
                            builder: (context) {
                              controller = context
                                  .di<FeatureFlowController<_State>>();
                              return Scaffold(
                                appBar: AppBar(leading: const McFlowBackButton()),
                              );
                            },
                          ),
                        ),
                        if (s.selected != null)
                          McFlowPage(
                            name: 'detail',
                            child: Builder(
                              builder: (context) => Scaffold(
                                appBar: AppBar(title: const Text('detail')),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      controller.update((_) => const _State('x'));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);

      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();

      expect(find.text('detail'), findsNothing);
      expect(controller.state.selected, isNull);
      expect(find.text('open'), findsNothing, reason: 'still inside the flow');
    });
  });

  testWidgets('T-0036-AC1 the back button is present after the root page '
      'rebuilds under an inner page', (tester) async {
    late FeatureFlowController<_State> controller;
    var locale = const Locale('en');
    late StateSetter setLocale;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setLocale = setState;
          return MaterialApp(
            theme: McTheme.light,
            locale: locale,
            supportedLocales: const [Locale('en'), Locale('de')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => FeatureFlow<_State>(
                        state: const _State(),
                        onGeneratePages: (s) => [
                          McFlowPage(
                            name: 'list',
                            child: Builder(
                              builder: (context) {
                                controller = context
                                    .di<FeatureFlowController<_State>>();
                                // Depends on the locale, so a locale change
                                // rebuilds this page even when covered.
                                final lang = Localizations.localeOf(
                                  context,
                                ).languageCode;
                                return Scaffold(
                                  appBar: AppBar(
                                    leading: const McFlowBackButton(),
                                    title: Text('flow root $lang'),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (s.selected != null)
                            McFlowPage(
                              name: 'detail',
                              child: Scaffold(
                                appBar: AppBar(title: const Text('detail')),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    controller.update((_) => const _State('x'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    // The root page rebuilds while the inner page is on top.
    setLocale(() => locale = const Locale('de'));
    await tester.pumpAndSettle();
    expect(find.text('flow root de', skipOffstage: false), findsOneWidget);

    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsNothing);
    expect(find.text('flow root de'), findsOneWidget);

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('flow root de'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('T-0034-AC1 FlowScope.of outside a flow names the problem', (
    tester,
  ) async {
    late BuildContext outside;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            outside = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      () => FlowScope.of(outside),
      throwsA(
        isA<FlutterError>().having(
          (e) => e.message,
          'message',
          contains('not below a FeatureFlow'),
        ),
      ),
    );
  });

  testWidgets('T-0034-AC6 flowStateOf fails when the scope has no controller', (
    tester,
  ) async {
    final container = (await tester.runAsync(createChildContainer))!;
    late BuildContext page;
    await tester.pumpWidget(
      _app(
        FlowScope(
          container: container,
          child: Builder(
            builder: (context) {
              page = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
      () => flowStateOf<_State>(page),
      throwsA(
        isA<StateError>().having(
          (e) => '$e',
          'message',
          contains('no controller'),
        ),
      ),
    );
  });
}

class _Probe extends StatefulWidget {
  const _Probe();

  static int inits = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.inits++;
  }

  @override
  Widget build(BuildContext context) => const Text('detail probe');
}

class _CustomMaterial extends DefaultMaterialLocalizations {
  const _CustomMaterial();

  @override
  String get okButtonLabel => 'CUSTOM-OK';
}

class _CustomMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _CustomMaterialDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      const _CustomMaterial();

  @override
  bool shouldReload(_CustomMaterialDelegate old) => false;
}
