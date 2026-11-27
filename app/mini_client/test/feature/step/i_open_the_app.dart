import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

/// Usage: I open the app
///
/// The real `MiniClientApp`: its boot, router, the 7 wirings and the app's
/// shell, over the test container (the session's backend harness, storage and
/// analytics sink). The router and the wirings are the app's own, so a screen
/// that tracks here tracks in the app.
Future<void> iOpenTheApp(WidgetTester tester) async {
  final session = McTestSession.current;
  final links = PendingLinks.install(tester.binding);
  addTearDown(links.detach);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: McFixtureAssetBundle(),
      child: MiniClientApp(
        links: links,
        initializers: (routerRef) => McTestContainer.initializers(
          session,
          wirings: [RouterDIInitializer(routerRef), ...wiringInitializers],
        ),
      ),
    ),
  );
  await tester.pump();
  await mcSettle(tester);
}
