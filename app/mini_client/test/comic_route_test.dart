// T-0041: comics_details inside the real app (the full root list, every
// wiring and the app's mock domains): the publishing route, the link from the
// characters preview, and the comic's way out to a character.
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

const _comicTitle = ValueKey<String>('comics_details.title');
const _comicBody = ValueKey<String>('comics_details.body');
const _cast = ValueKey<String>('comics_details.cast');

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
    storage = Directory.systemTemp.createTempSync('comic_route_test');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester) async {
    // The iPhone 17 Pro surface (mcReferenceSurface), not the 800x600 default.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
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
  }

  testWidgets('T-0041-AC5 the link miniclient://app/comics/501500 opens the '
      'comic page over the app mock domains', (tester) async {
    await boot(tester);

    await _pushLink(tester, 'miniclient://app/comics/501500');
    await tester.pumpAndSettle();

    expect(find.byKey(_comicTitle), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(_comicTitle)).data,
      'Amber Frontier #1',
    );
    expect(find.text('Add to favourites'), findsOneWidget);
  });

  testWidgets('T-0041-AC5 home, Characters, a preview and a related comic '
      'open the comic page', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amber Alchemist'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Amber Requiem #8'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Amber Requiem #8'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(_comicTitle)).data,
      'Amber Requiem #8',
    );
  });

  testWidgets('T-0041-AC3 in the app, a cast member opens the characters '
      'placeholder', (tester) async {
    await boot(tester);
    await _pushLink(tester, 'miniclient://app/comics/501500');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(_cast),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(_comicBody),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Amber Vanguard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amber Vanguard').hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('character.details.placeholder')),
      findsOneWidget,
    );
    expect(find.text('Character details 100366'), findsOneWidget);
  });
}
