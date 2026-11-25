import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_sandbox/src/universe_sandbox_router.dart';
import 'package:universe_wiring/universe_wiring.dart';

class _Targets implements RouteTargets {
  @override
  Widget characters(BuildContext context) =>
      const SizedBox(key: Key('fake.characters'));

  @override
  Widget characterDetails(BuildContext context, int id) =>
      CharacterDetailsPlaceholderPage(id: id);
}

void main() {
  setUp(() async {
    await resetDIContainer();
    await initializeDIContainer([
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<RouteTargets>(_Targets());
      }),
    ]);
  });
  tearDown(resetDIContainer);

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    final router = buildSandboxRouter(initialLocation: location);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('T-0033-AC3 the sandbox opens on the characters list', (
    tester,
  ) async {
    final router = await pump(tester, AppLocations.home);

    expect(router.state.uri.toString(), AppLocations.characters);
    expect(find.byKey(const Key('fake.characters')), findsOneWidget);
  });

  testWidgets('T-0033-AC3 a route of another group shows the stub page', (
    tester,
  ) async {
    await pump(tester, AppLocations.placeholder(3));

    expect(find.byKey(const Key('sandbox.stub')), findsOneWidget);
  });
}
