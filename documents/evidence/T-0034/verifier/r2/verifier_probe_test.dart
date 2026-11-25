// T-0034 Verifier probes (temporary; never committed).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';
import 'package:mc_feature_flow/testing.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

class _Provided {
  const _Provided(this.label);
  final String label;
}

class _NeedsProvided {
  const _NeedsProvided(this.provided);
  final _Provided provided;
}

class _State {
  const _State([this.selected]);
  final String? selected;
}

class _CustomMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _CustomMaterialDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(_CustomMaterial());
  @override
  bool shouldReload(_CustomMaterialDelegate old) => false;
}

class _CustomMaterial extends DefaultMaterialLocalizations {
  @override
  String get okButtonLabel => 'CUSTOM-OK';
}

class _StringsDelegate extends LocalizationsDelegate<String> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<String> load(Locale locale) =>
      SynchronousFuture<String>('flow-${locale.languageCode}');
  @override
  bool shouldReload(_StringsDelegate old) => false;
}

Widget _app(
  Widget home, {
  Locale locale = const Locale('en'),
  List<LocalizationsDelegate<Object?>> delegates =
      GlobalMaterialLocalizations.delegates,
}) => MaterialApp(
  theme: McTheme.light,
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('de')],
  localizationsDelegates: delegates,
  home: Scaffold(body: home),
);

void main() {
  setUp(() async {
    await resetDIContainer();
    await initializeDIContainer(const []);
  });
  tearDown(resetDIContainer);

  testWidgets('P1 provide: is resolvable by the flow initializer', (
    tester,
  ) async {
    String? got;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State(),
          provide: (scope) =>
              scope.registerSingleton<_Provided>(const _Provided('nav')),
          flowInitializer: McDIInitializer((getIt, _) {
            // Eager use inside the initializer, as injectable would for a
            // singleton that needs the navigator.
            final provided = getIt<_Provided>();
            getIt.registerSingleton<_NeedsProvided>(_NeedsProvided(provided));
          }),
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'list',
              child: Builder(
                builder: (context) {
                  got = context.di<_NeedsProvided>().provided.label;
                  return const Text('ok');
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(got, 'nav');
  });

  testWidgets('P2 after dispose: provided not reachable, di on stale context', (
    tester,
  ) async {
    late BuildContext page;
    late ChildDIContainer captured;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State(),
          provide: (scope) =>
              scope.registerSingleton<_Provided>(const _Provided('nav')),
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'list',
              child: Builder(
                builder: (context) {
                  page = context;
                  captured = FlowScope.read(context).container;
                  return const Text('ok');
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(page.di<_Provided>().label, 'nav');

    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    Object? staleDi;
    try {
      page.di<_Provided>();
    } on Object catch (e) {
      staleDi = e;
    }
    Object? staleContainer;
    try {
      captured<_Provided>();
    } on Object catch (e) {
      staleContainer = e;
    }
    Object? staleHook;
    try {
      flowStateOf<_State>(page);
    } on Object catch (e) {
      staleHook = e;
    }
    // ignore: avoid_print
    print('P2 staleDi=${staleDi.runtimeType}: $staleDi');
    // ignore: avoid_print
    print('P2 staleContainer=${staleContainer.runtimeType}: $staleContainer');
    // ignore: avoid_print
    print('P2 staleHook=${staleHook.runtimeType}: $staleHook');
    expect(diContainer.isRegistered<_Provided>(), isFalse);
    expect(staleDi, isNotNull, reason: 'di on an unmounted page context');
    expect(staleContainer, isNotNull, reason: 'the disposed container');
  });

  testWidgets('P3 delegates list: duplicates and host overrides', (
    tester,
  ) async {
    late BuildContext page;
    await tester.pumpWidget(
      _app(
        delegates: const [
          _CustomMaterialDelegate(),
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          McL10nCoreL10n.delegate,
        ],
        FeatureFlow<_State>(
          state: const _State(),
          localizationsDelegates: const [_StringsDelegate()],
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'list',
              child: Builder(
                builder: (context) {
                  page = context;
                  return const Text('ok');
                },
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final locs = tester
        .widgetList<Localizations>(find.byType(Localizations))
        .toList();
    final inner = locs.last;
    final names = [for (final d in inner.delegates) '${d.runtimeType}'];
    // ignore: avoid_print
    print('P3 localizations widgets=${locs.length}; inner delegates=$names');
    final counts = <String, int>{};
    for (final n in names) {
      counts[n] = (counts[n] ?? 0) + 1;
    }
    // ignore: avoid_print
    print('P3 duplicates=${counts.entries.where((e) => e.value > 1).toList()}');
    // ignore: avoid_print
    print(
      'P3 host custom MaterialLocalizations okButtonLabel inside the flow = '
      '${MaterialLocalizations.of(page).okButtonLabel}',
    );
    // ignore: avoid_print
    print('P3 flow string = ${Localizations.of<String>(page, String)}');
  });

  testWidgets('P4 nested flow: outer provide: not visible in inner flow; '
      'hook returns innermost state', (tester) async {
    Object? innerErr;
    late BuildContext inner;
    await tester.pumpWidget(
      _app(
        FeatureFlow<_State>(
          state: const _State('outer'),
          provide: (scope) =>
              scope.registerSingleton<_Provided>(const _Provided('nav')),
          onGeneratePages: (_) => [
            McFlowPage(
              name: 'outer',
              child: FeatureFlow<String>(
                state: 'inner',
                onGeneratePages: (_) => [
                  McFlowPage(
                    name: 'inner',
                    child: Builder(
                      builder: (context) {
                        inner = context;
                        try {
                          context.di<_Provided>();
                        } on Object catch (e) {
                          innerErr = e;
                        }
                        return const Text('inner');
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
    // ignore: avoid_print
    print('P4 innerErr=${innerErr.runtimeType}');
    expect(innerErr, isNotNull);
    expect(flowStateOf<String>(inner), 'inner');
  });

  testWidgets('P5 bare host: core strings inside the flow', (tester) async {
    late BuildContext page;
    await tester.pumpWidget(
      MaterialApp(
        theme: McTheme.light,
        home: Scaffold(
          body: FeatureFlow<_State>(
            state: const _State(),
            localizationsDelegates: const [_StringsDelegate()],
            onGeneratePages: (_) => [
              McFlowPage(
                name: 'list',
                child: Builder(
                  builder: (context) {
                    page = context;
                    return const Text('ok');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print(
      'P5 core=${McL10nCoreL10n.of(page).commonRetry} '
      'flow=${Localizations.of<String>(page, String)} '
      'material=${MaterialLocalizations.of(page).okButtonLabel}',
    );
  });

  testWidgets('P6 flowLeading on the root page after it rebuilt while an inner '
      'page was on top', (tester) async {
    FeatureFlowController<_State> controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: McTheme.light,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => FeatureFlow<_State>(
                    state: const _State(),
                    onGeneratePages: (s) => [
                      const McFlowPage(name: 'root', child: _RootPage()),
                      if (s.selected != null)
                        const McFlowPage(
                          name: 'inner',
                          child: Scaffold(body: Text('inner')),
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
    controller = _RootPage.controller!;
    final before = find.byType(BackButton).evaluate().length;
    controller.update((_) => const _State('x'));
    await tester.pumpAndSettle();
    _RootPage
        .rebuild
        .value++; // e.g. a locale or theme change while the inner page is up
    await tester.pumpAndSettle();
    controller.update((_) => const _State());
    await tester.pumpAndSettle();
    final after = find.byType(BackButton).evaluate().length;
    // ignore: avoid_print
    print('P6 root back buttons before=$before after=$after');
  });
}

class _RootPage extends StatelessWidget {
  const _RootPage();
  static final rebuild = ValueNotifier<int>(0);
  static FeatureFlowController<_State>? controller;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: rebuild,
    builder: (context, _, _) {
      controller = context.di<FeatureFlowController<_State>>();
      return Scaffold(
        appBar: AppBar(
          leading: context.flowLeading(),
          title: const Text('root'),
        ),
      );
    },
  );
}
