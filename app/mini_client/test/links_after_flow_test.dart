import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

/// What iOS sends for a link once the app runs.
Future<void> _pushLink(WidgetTester tester, String location) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {
          'location': location,
          'state': null,
        }),
      ),
      (_) {},
    );

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('links_after_flow_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  // R1 (the T-0033 re-verification): flow_builder 0.1.0 replaced the
  // `flutter/navigation` handler once a flow mounted and dropped
  // `pushRouteInformation`, so a link sent to the running app was lost. The
  // vendored flow_builder forwards it (T-0035).
  testWidgets(
    'T-0033-AC4 a link sent to the running app opens its route after the '
    'characters list (a flow) is shown',
    (tester) async {
      final links = PendingLinks.install(tester.binding);
      addTearDown(links.detach);
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: McFixtureAssetBundle(),
          child: MiniClientApp(
            links: links,
            initializers: (routerRef) => rootInitializers(
              config: () async => _config,
              storageDirectory: storage,
              monitoringSinks: [InMemorySink()],
              mockDomains: appMockDomains,
              routerRef: routerRef,
              wirings: wiringInitializers,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Characters'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('characters_list.grid')),
        findsOneWidget,
        reason: 'the flow is on screen',
      );

      await _pushLink(tester, 'miniclient://app/placeholder/42');
      await tester.pumpAndSettle();

      expect(find.text('Placeholder detail 42'), findsOneWidget);
    },
  );
}
