import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';

GoRouter _router([String initialLocation = '/']) => GoRouter(
  initialLocation: initialLocation,
  routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
);

void main() {
  setUp(resetDIContainer);
  tearDown(resetDIContainer);

  test('T-0033-AC1 RouterRef hands out the attached router, then none after '
      'detach', () {
    final ref = RouterRef();
    expect(() => ref.router, throwsStateError);
    final router = _router();
    addTearDown(router.dispose);

    expect(ref.attach(router), same(router));
    expect(ref.router, same(router));
    ref.detach();
    ref.detach();

    expect(() => ref.router, throwsStateError);
  });

  test('T-0033-AC1 RouterDIInitializer resolves whatever router is attached '
      'now, never a cached one', () async {
    final ref = RouterRef();
    await initializeDIContainer([RouterDIInitializer(ref)]);
    final first = _router();
    final second = _router();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    ref.attach(first);
    expect(diContainer<GoRouter>(), same(first));
    ref.attach(second);
    expect(diContainer<GoRouter>(), same(second));
    ref.detach();
    expect(() => diContainer<GoRouter>(), throwsStateError);
  });

  testWidgets('T-0033-AC1 McApp attaches its router and detaches it when it '
      'is disposed', (tester) async {
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    final ref = RouterRef();

    await tester.pumpWidget(
      McApp(
        boot: () async {},
        router: (_) => _router(),
        links: links,
        routerRef: ref,
      ),
    );
    await tester.pump();
    expect(ref.router, isA<GoRouter>());

    await tester.pumpWidget(const SizedBox());

    expect(() => ref.router, throwsStateError);
  });

  test('T-0033-AC3 a link scheme accepts only its own scheme and host', () {
    const sandbox = LinkScheme('miniclientuniverse', 'app');

    expect(
      PendingLinks.normalise(
        'miniclientuniverse://app/characters/7',
        scheme: sandbox,
      ),
      '/characters/7',
    );
    expect(
      PendingLinks.normalise('miniclient://app/characters/7', scheme: sandbox),
      '/',
      reason: "the main app's scheme is foreign to the sandbox",
    );
    expect(
      PendingLinks.normalise('miniclientuniverse://app/characters/7'),
      '/',
      reason: 'and the other way round (the default is miniclient://app)',
    );
    expect(sandbox.isForeign(Uri.parse('/characters')), isFalse);
    expect(sandbox.isForeign(Uri.parse('miniclientuniverse://evil/x')), isTrue);
  });

  testWidgets('T-0033-AC3 PendingLinks with a scheme keeps its cold-start and '
      "pushed links, and drops the main app's", (tester) async {
    const sandbox = LinkScheme('miniclientuniverse', 'app');
    tester.platformDispatcher.defaultRouteNameTestValue =
        'miniclientuniverse://app/characters';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    final links = PendingLinks.install(tester.binding, scheme: sandbox);
    addTearDown(links.detach);
    expect(links.pending, '/characters');

    await tester.binding.handlePushRoute('miniclient://app/characters/9');
    expect(links.pending, '/');
    await tester.binding.handlePushRoute(
      'miniclientuniverse://app/characters/9',
    );
    expect(links.take(), '/characters/9');
  });
}
