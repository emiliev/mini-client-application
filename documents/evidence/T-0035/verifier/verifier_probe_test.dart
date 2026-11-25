// T-0035 Verifier probes (temporary: copied into utility/mc_feature_flow/test/
// with a scratch BUILD target for the run, never committed there).
//
// Test ORDER matters: the `BASELINE` cases run first, before any FlowBuilder
// has ever mounted in this process, so they answer through the framework's own
// `WidgetsBinding._handleNavigationInvocation`. Every later case is compared
// against those recordings.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_ds_theme/mc_ds_theme.dart';
import 'package:mc_feature_flow/mc_feature_flow.dart';

class _S {
  const _S({this.pushed = false});
  final bool pushed;
}

class _Delegate extends RouterDelegate<Uri> with ChangeNotifier {
  _Delegate(this.body);
  final ValueListenable<Widget> body;
  final List<Uri> locations = [];
  final List<Object?> states = [];
  bool popResult = false;
  int pops = 0;

  @override
  Uri? get currentConfiguration => locations.isEmpty ? null : locations.last;

  @override
  Future<void> setNewRoutePath(Uri configuration) async =>
      locations.add(configuration);

  @override
  Future<bool> popRoute() async {
    pops++;
    return popResult;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Widget>(
    valueListenable: body,
    builder: (context, child, _) => Scaffold(body: child),
  );
}

class _Parser extends RouteInformationParser<Uri> {
  _Parser(this.states);
  final List<Object?> states;
  @override
  Future<Uri> parseRouteInformation(RouteInformation info) async {
    states.add(info.state);
    return info.uri;
  }

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

Widget _flow(String tag, {Widget? nested, bool pushed = false}) =>
    FeatureFlow<_S>(
      state: _S(pushed: pushed),
      onGeneratePages: (s) => [
        McFlowPage(name: 'root', child: nested ?? Text('$tag root')),
        if (s.pushed) McFlowPage(name: 'detail', child: Text('$tag detail')),
      ],
    );

/// Sends like the engine: an inbound platform message; returns the decoded reply.
Future<Object?> _send(WidgetTester t, String method, [Object? args]) async {
  Object? reply = #none;
  await t.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    const JSONMethodCodec().encodeMethodCall(MethodCall(method, args)),
    (data) => reply = data == null
        ? null
        : const JSONMethodCodec().decodeEnvelope(data),
  );
  await t.pumpAndSettle();
  return reply;
}

int _systemPops = 0;
void _countSystemPops(WidgetTester t) {
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') {
        _systemPops++;
      }
      return null;
    },
  );
}

Future<_Delegate> _mount(WidgetTester t, ValueNotifier<Widget> body) async {
  final d = _Delegate(body);
  await t.pumpWidget(
    MaterialApp.router(
      theme: McTheme.light.copyWith(platform: TargetPlatform.iOS),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerDelegate: d,
      routeInformationParser: _Parser(d.states),
    ),
  );
  await t.pumpAndSettle();
  return d;
}

const _qf = '/a/b?q=1&r=x%20y#frag';
const _iosLink = 'miniclient://app/characters/6?tab=info#bio';

/// The same script for the baseline and the after-dispose run.
Future<List<Object?>> _script(WidgetTester t, _Delegate d) async {
  final out = <Object?>[];
  _systemPops = 0;
  d.pops = 0;
  out.add([
    'link',
    await _send(t, 'pushRouteInformation', {'location': _qf}),
    d.locations.last.toString(),
  ]);
  out.add([
    'ioslink',
    await _send(t, 'pushRouteInformation', {'location': _iosLink}),
    d.locations.last.toString(),
  ]);
  out.add([
    'legacy',
    await _send(t, 'pushRoute', '/legacy?z=2#f'),
    d.locations.last.toString(),
  ]);
  d.popResult = true;
  out.add(['pop-handled', await _send(t, 'popRoute'), d.pops, _systemPops]);
  d.popResult = false;
  out.add(['pop-unhandled', await _send(t, 'popRoute'), d.pops, _systemPops]);
  out.add(['unknown', await _send(t, 'nope')]);
  out.add([
    'withState',
    await _send(t, 'pushRouteInformation', {'location': '/s', 'state': 'st'}),
    d.locations.last.toString(),
    d.states.last,
  ]);
  return out;
}

GoRouter _go() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => Scaffold(body: Text('home ${s.uri}')),
    ),
    GoRoute(
      path: '/items/:id',
      builder: (c, s) => Scaffold(body: Text('items ${s.uri}')),
    ),
    GoRoute(
      path: '/flow',
      builder: (c, s) => Scaffold(body: _flow('go', pushed: true)),
    ),
  ],
);

Future<List<Object?>> _goScript(WidgetTester t, GoRouter r) async {
  final out = <Object?>[];
  out.add([
    'go-link',
    await _send(t, 'pushRouteInformation', {
      'location': '/items/7?tab=info#sec',
    }),
    r.state.uri.toString(),
    find.text('items /items/7?tab=info#sec').evaluate().length,
  ]);
  out.add([
    'go-ios',
    await _send(t, 'pushRouteInformation', {
      'location': 'miniclient://app/items/8?x=1#y',
    }),
    r.state.uri.toString(),
  ]);
  r.go('/');
  await t.pumpAndSettle();
  unawaited(r.push<void>('/items/9'));
  await t.pumpAndSettle();
  out.add(['go-pop', await _send(t, 'popRoute'), r.state.uri.toString()]);
  return out;
}

List<Object?>? baseline;

/// Equal to the framework baseline except the accepted gap: the
/// `pushRouteInformation` state is dropped (TL accepted; iOS sends none).
void _expectBaseline(List<Object?> got) {
  expect(
    got.sublist(0, got.length - 1).toString(),
    baseline!.sublist(0, baseline!.length - 1).toString(),
  );
  expect(got.last.toString(), '[withState, true, /s, null]');
  expect(baseline!.last.toString(), '[withState, true, /s, st]');
}

List<Object?>? goBaseline;

void main() {
  setUp(() async {
    await resetDIContainer();
    await initializeDIContainer(const []);
  });
  tearDown(resetDIContainer);

  testWidgets('BASELINE framework handler, no flow ever mounted', (t) async {
    _countSystemPops(t);
    final d = await _mount(t, ValueNotifier<Widget>(const Text('no flow')));
    baseline = await _script(t, d);
    debugPrint('VPROBE baseline $baseline');
  });

  testWidgets('BASELINE go_router, no flow ever mounted', (t) async {
    final r = _go();
    await t.pumpWidget(
      MaterialApp.router(theme: McTheme.light, routerConfig: r),
    );
    await t.pumpAndSettle();
    goBaseline = await _goScript(t, r);
    debugPrint('VPROBE goBaseline $goBaseline');
  });

  testWidgets(
    'VPROBE1 query+fragment, two links in a row, link with inner page open',
    (t) async {
      final body = ValueNotifier<Widget>(_flow('f', pushed: true));
      final d = await _mount(t, body);
      expect(find.text('f detail'), findsOneWidget);
      final r1 = await _send(t, 'pushRouteInformation', {'location': _qf});
      final r2 = await _send(t, 'pushRouteInformation', {
        'location': '/second?x=2',
      });
      debugPrint('VPROBE1 replies $r1 $r2 locations ${d.locations}');
      expect(r1, true, reason: 'iOS treats a non-true reply as unhandled');
      expect(r2, true);
      expect(
        d.locations
            .map((u) => u.toString())
            .toList()
            .sublist(d.locations.length - 2),
        [_qf, '/second?x=2'],
      );
      expect(d.locations[d.locations.length - 2].fragment, 'frag');
      expect(d.locations[d.locations.length - 2].queryParameters, {
        'q': '1',
        'r': 'x y',
      });
      // The flow's inner page is untouched by a link the router ignores visually.
      expect(find.text('f detail'), findsOneWidget);
    },
  );

  testWidgets('VPROBE2 after dispose: identical to the no-flow baseline', (
    t,
  ) async {
    _countSystemPops(t);
    final body = ValueNotifier<Widget>(_flow('f', pushed: true));
    final d = await _mount(t, body);
    body.value = const Text('no flow');
    await t.pumpAndSettle();
    final after = await _script(t, d);
    debugPrint('VPROBE2 after $after');
    _expectBaseline(after);
  });

  testWidgets(
    'VPROBE3 nested: innermost first, then falls through while mounted',
    (t) async {
      _countSystemPops(t);
      _systemPops = 0;
      final body = ValueNotifier<Widget>(
        _flow('outer', nested: _flow('inner', pushed: true)),
      );
      final d = await _mount(t, body);
      expect(find.text('inner detail'), findsOneWidget);
      final p1 = await _send(t, 'popRoute');
      expect(find.text('inner detail'), findsNothing);
      expect(find.text('inner root'), findsOneWidget);
      expect(d.pops, 0);
      final p2 = await _send(t, 'popRoute');
      debugPrint(
        'VPROBE3 replies $p1 $p2 pops ${d.pops} systemPops $_systemPops exception ${t.takeException()}',
      );
      expect(d.pops, 1, reason: 'second pop falls through to the router');
      expect(
        _systemPops,
        1,
        reason: 'router did not handle it -> SystemNavigator.pop, as framework',
      );
      // Observation (stock flow_builder `_pop`: at its root it pops its own
      // navigator's last page before falling through).
      debugPrint(
        'VPROBE3 inner root after fall-through: '
        '${find.text('inner root').evaluate().length}',
      );
    },
  );

  testWidgets('VPROBE3b nested, both levels pushed (observation)', (t) async {
    final body = ValueNotifier<Widget>(
      _flow('outer', pushed: true, nested: _flow('inner', pushed: true)),
    );
    final d = await _mount(t, body);
    await _send(t, 'popRoute');
    debugPrint(
      'VPROBE3b after pop1: inner detail=${find.text('inner detail', skipOffstage: false).evaluate().length} '
      'outer detail=${find.text('outer detail').evaluate().length} pops=${d.pops}',
    );
    await _send(t, 'popRoute');
    debugPrint(
      'VPROBE3b after pop2: inner detail=${find.text('inner detail', skipOffstage: false).evaluate().length} '
      'outer detail=${find.text('outer detail').evaluate().length} pops=${d.pops}',
    );
  });

  testWidgets(
    'VPROBE4 two sibling flows, dispose the second, channel still works',
    (t) async {
      _countSystemPops(t);
      final body = ValueNotifier<Widget>(
        Column(
          children: [
            Expanded(
              child: HeroControllerScope.none(
                child: _flow('one', pushed: true),
              ),
            ),
            Expanded(
              child: HeroControllerScope.none(
                child: _flow('two', pushed: true),
              ),
            ),
          ],
        ),
      );
      final d = await _mount(t, body);
      expect(find.text('one detail'), findsOneWidget);
      expect(find.text('two detail'), findsOneWidget);
      body.value = Column(
        children: [
          Expanded(
            child: HeroControllerScope.none(child: _flow('one', pushed: true)),
          ),
        ],
      );
      await t.pumpAndSettle();
      expect(find.text('two detail'), findsNothing);
      expect(
        await _send(t, 'pushRouteInformation', {'location': '/sib?a=1#b'}),
        true,
      );
      expect(d.locations.last.toString(), '/sib?a=1#b');
      // Flow one is still mounted: its pushed page takes the first pop.
      await _send(t, 'popRoute');
      expect(find.text('one detail'), findsNothing);
      expect(d.pops, 0);
      await _send(t, 'popRoute');
      expect(d.pops, 1);
      body.value = const Text('no flow');
      await t.pumpAndSettle();
      _expectBaseline(await _script(t, d));
    },
  );

  testWidgets(
    'VPROBE5 go_router: flow route with inner page open, links reach go_router',
    (t) async {
      final r = _go();
      await t.pumpWidget(
        MaterialApp.router(theme: McTheme.light, routerConfig: r),
      );
      await t.pumpAndSettle();
      expect(
        await _send(t, 'pushRouteInformation', {'location': '/flow'}),
        true,
      );
      debugPrint(
        'VPROBE5 after /flow: ${r.state.uri} '
        'shown=${find.textContaining('go ').evaluate().map((e) => (e.widget as Text).data).toList()}',
      );
      expect(find.text('go detail'), findsOneWidget);
      final res = await _goScript(t, r);
      debugPrint('VPROBE5 $res');
      expect(res.toString(), goBaseline.toString());
      // Re-mount the flow and send two links in a row.
      await _send(t, 'pushRouteInformation', {'location': '/flow'});
      expect(find.text('go detail'), findsOneWidget);
      await _send(t, 'pushRouteInformation', {'location': '/items/1?a=1'});
      await _send(t, 'pushRouteInformation', {'location': '/items/2#z'});
      expect(r.state.uri.toString(), '/items/2#z');
      expect(find.text('items /items/2#z'), findsOneWidget);
    },
  );
}
