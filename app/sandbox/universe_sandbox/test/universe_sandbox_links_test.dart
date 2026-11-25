import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:universe_sandbox/src/universe_sandbox_app.dart';
import 'package:universe_sandbox/src/universe_sandbox_router.dart';
import 'package:universe_wiring/universe_wiring.dart';

import 'fake_targets.dart';

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

const _details = Key('character.details.placeholder');
const _list = Key('fake.characters');

void main() {
  setUp(resetDIContainer);
  tearDown(resetDIContainer);

  Widget app(PendingLinks links, {Future<void>? hold}) => UniverseSandboxApp(
    links: links,
    initializers: (routerRef) => [
      RouterDIInitializer(routerRef),
      McDIInitializer((getIt, _) {
        getIt.registerSingleton<RouteTargets>(FakeTargets());
      }),
      if (hold != null) McDIInitializer((_, _) => hold),
    ],
  );

  PendingLinks install(WidgetTester tester, {String? coldStart}) {
    if (coldStart != null) {
      tester.platformDispatcher.defaultRouteNameTestValue = coldStart;
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    }
    final links = PendingLinks.install(
      tester.binding,
      scheme: sandboxLinkScheme,
    );
    addTearDown(links.detach);
    return links;
  }

  testWidgets('T-0033-AC3 a cold-start link of the sandbox scheme opens its '
      'route', (tester) async {
    final links = install(
      tester,
      coldStart: 'miniclientuniverse://app/characters/7',
    );

    await tester.pumpWidget(app(links));
    await tester.pumpAndSettle();

    expect(find.byKey(_details), findsOneWidget);
    expect(find.text('Character details 7'), findsOneWidget);
  });

  testWidgets('T-0033-AC3 a cold-start link of the main app scheme is not the '
      "sandbox's: it opens the list", (tester) async {
    final links = install(tester, coldStart: 'miniclient://app/characters/7');

    await tester.pumpWidget(app(links));
    await tester.pumpAndSettle();

    expect(find.byKey(_list), findsOneWidget);
    expect(find.byKey(_details), findsNothing);
  });

  testWidgets('T-0033-AC3 a sandbox link that arrives during boot is held and '
      'opened once boot is ready', (tester) async {
    final links = install(tester);
    final hold = Completer<void>();

    await tester.pumpWidget(app(links, hold: hold.future));
    await tester.pump();
    await _pushLink(tester, 'miniclientuniverse://app/characters/5');
    expect(find.byKey(_details), findsNothing, reason: 'still booting');
    hold.complete();
    await tester.pumpAndSettle();

    expect(find.text('Character details 5'), findsOneWidget);
  });

  testWidgets('T-0033-AC3 a foreign link that arrives after boot is ignored '
      'the same way as a cold-start one', (tester) async {
    final links = install(tester);

    await tester.pumpWidget(app(links));
    await tester.pumpAndSettle();
    await _pushLink(tester, 'miniclient://app/characters/7');
    await tester.pumpAndSettle();

    expect(find.byKey(_list), findsOneWidget);
    expect(find.byKey(_details), findsNothing);
  });

  testWidgets('T-0033-AC3 a sandbox link that arrives after boot opens its '
      'route', (tester) async {
    final links = install(tester);

    await tester.pumpWidget(app(links));
    await tester.pumpAndSettle();
    await _pushLink(tester, 'miniclientuniverse://app/characters/8');
    await tester.pumpAndSettle();

    expect(find.text('Character details 8'), findsOneWidget);
  });
}
