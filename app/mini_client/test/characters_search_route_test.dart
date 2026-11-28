// T-0071: characters_search inside the real app (the full root list, every
// wiring and the app's mock domains): the route, the list's search action,
// the cold link, and the result's way out to the profile.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _searchField = ValueKey<String>('characters_search.field');
const _results = ValueKey<String>('characters_search.results');
const _grid = ValueKey<String>('characters_list.grid');
const _characterName = ValueKey<String>('characters_details.name');

/// The fixture facts (seed 42): the characters whose name starts with
/// [prefix], in name order, from the fixture's own cast.
List<CharacterRecord> _matches(String prefix) => [
  for (final c in CharacterUniverse(42, defaultMockClock).byName)
    if (c.name.toLowerCase().startsWith(prefix)) c,
];

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

/// The recent searches live in a real file (mc_storage): under fake time a
/// read or write completes only once real time passes (F-0038 fact 1). This
/// alternates real time and settling, so the search's history read and its
/// saves finish.
Future<void> _settleRealIo(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pumpAndSettle();
  }
}

String _fieldText(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(_searchField),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('characters_search_route');
  });

  tearDown(() async {
    await resetDIContainer();
    storage.deleteSync(recursive: true);
  });

  Future<void> boot(WidgetTester tester, {String? coldStartLink}) async {
    // The iPhone 17 Pro surface (mcReferenceSurface), not the 800x600 default.
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = mcReferenceSurface;
    addTearDown(tester.view.reset);
    final links = PendingLinks.install(tester.binding);
    addTearDown(links.detach);
    if (coldStartLink != null) {
      links.offer(coldStartLink);
    }
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

  testWidgets('T-0071-AC5 a cold-start link to the search opens it with its '
      'results, over the list and home', (tester) async {
    await boot(tester, coldStartLink: 'miniclient://app/characters/search?q=a');
    await _settleRealIo(tester);

    expect(find.byKey(const Key('home.placeholder')), findsNothing);
    expect(_fieldText(tester), 'a');
    expect(find.text(_matches('a').first.name), findsOneWidget);

    final router = diContainer<RouterRef>().router;
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_grid), findsOneWidget, reason: 'the list is below');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.placeholder')), findsOneWidget);
  });

  testWidgets('T-0071-AC5 a link to the running app opens the search with '
      'its query', (tester) async {
    await boot(tester);

    await _pushLink(tester, 'miniclient://app/characters/search?q=spi');
    await _settleRealIo(tester);

    expect(_fieldText(tester), 'spi');
    expect(find.text(_matches('spi').first.name), findsOneWidget);
  });

  testWidgets('T-0071-AC4 home, Characters, the search action, typing and a '
      'result open the profile; Back returns to the results', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Characters'));
    await _settleRealIo(tester);
    expect(find.byKey(_grid), findsOneWidget);
    await tester.tap(find.byTooltip('Search characters'));
    await _settleRealIo(tester);
    expect(find.byKey(_searchField), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'amber');
    await _settleRealIo(tester);
    final character = _matches('amber').first;
    final row = find.descendant(
      of: find.byKey(_results),
      matching: find.text(character.name),
    );
    expect(row, findsOneWidget);
    await tester.tap(row.hitTestable());
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(_characterName)).data,
      character.name,
    );

    // Back returns to the results, still for "amber".
    final router = diContainer<RouterRef>().router;
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_characterName), findsNothing);
    expect(_fieldText(tester), 'amber');
    expect(row, findsOneWidget);
  });
}
