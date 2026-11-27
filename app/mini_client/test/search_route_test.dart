// T-0046: discovery_search inside the real app (the full root list, every
// wiring and the app's mock domains): the discovery route, the Search entry
// on home, and the results' ways out to a comic and a character.
import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_fixtures_discovery/mc_fixtures_discovery.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_test_utils/mc_test_utils.dart';
import 'package:mini_client/src/mini_client_app.dart';

const _config =
    '{"env":"e2e","backend":{"seed":42,"latencyMs":0,"scenario":"happy"},'
    '"apiBaseUrl":"https://mock.mini-client.invalid/","build":"1"}';

const _searchField = ValueKey<String>('discovery_search.field');
const _results = ValueKey<String>('discovery_search.results');
const _comicTitle = ValueKey<String>('comics_details.title');
const _characterName = ValueKey<String>('characters_details.name');

/// The fixture facts (seed 42): the first character and the first comic for
/// "spi", from the discovery fixture's own ranking.
final SearchIndex _index = SearchIndex.fromUniverses(42, defaultMockClock);
SearchEntry _first(String type) =>
    _index.search('spi', types: [type]).first.entry;

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

void main() {
  late Directory storage;

  setUp(() async {
    await resetDIContainer();
    storage = Directory.systemTemp.createTempSync('search_route_test');
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

  Future<void> tapResult(WidgetTester tester, String title) async {
    final row = find.descendant(
      of: find.byKey(_results),
      matching: find.text(title),
    );
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(_results),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row.hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('T-0046-AC5 the link miniclient://app/search?q=spi opens the '
      'search with its results over the app mock domains', (tester) async {
    await boot(tester);

    await _pushLink(tester, 'miniclient://app/search?q=spi');
    await _settleRealIo(tester);

    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(_searchField),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'spi',
    );
    expect(find.text(_first('character').title), findsOneWidget);
    expect(find.text(_first('comic').title), findsOneWidget);
  });

  testWidgets('T-0046-AC5 a cold-start link to the search opens it with its '
      'results', (tester) async {
    await boot(tester, coldStartLink: 'miniclient://app/search?q=spi');
    await _settleRealIo(tester);

    expect(find.byKey(const Key('home.placeholder')), findsNothing);
    expect(find.text(_first('character').title), findsOneWidget);
  });

  testWidgets('T-0046-AC5 home, Search, typing spi and a comic open the comic '
      'page', (tester) async {
    await boot(tester);

    await tester.tap(find.text('Search'));
    await _settleRealIo(tester);
    await tester.enterText(find.byType(EditableText), 'spi');
    await _settleRealIo(tester);
    final comic = _first('comic');
    await tapResult(tester, comic.title);

    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, comic.title);

    // Back returns to the results, still for "spi".
    final router = diContainer<RouterRef>().router;
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(_comicTitle), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(comic.title),
      ),
      findsOneWidget,
    );
  });

  testWidgets('T-0046-AC3 in the app, a character result opens the '
      'character profile', (tester) async {
    await boot(tester);
    await _pushLink(tester, 'miniclient://app/search?q=spi');
    await _settleRealIo(tester);

    final character = _first('character');
    await tapResult(tester, character.title);

    expect(
      tester.widget<Text>(find.byKey(_characterName)).data,
      character.title,
    );
  });
}
