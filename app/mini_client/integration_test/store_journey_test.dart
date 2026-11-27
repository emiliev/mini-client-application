import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _storeBody = ValueKey<String>('store_home.body');
const _categoryGrid = ValueKey<String>('store_category.grid');
const _comicTitle = ValueKey<String>('comics_details.title');

// Fixture facts (mc_fixtures_commerce CONTRACT.md, seed 42): the first deal,
// and the 1st and 21st products of `heroes` in title order (page 2 starts at
// the 21st, the page size being 20).
const _firstDeal = 'Amber Frontier #2';
const _firstHero = 'Ember Chronicles #1';
const _twentyFirstHero = 'Ember Reckoning #3';

Finder _inStore(String text) =>
    find.descendant(of: find.byKey(_storeBody), matching: find.text(text));

Finder _storeScrollable() => find
    .descendant(of: find.byKey(_storeBody), matching: find.byType(Scrollable))
    .first;

/// T-0056-AC5 on a simulator, through the real `main()`: home, Store, the
/// sections, a deal and its comic page; Back to the store; a category inside
/// the store, scrolled to its end so page 2 loads. Run through
/// `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0056-AC5 home to the store, a deal and its comic, back, a '
      'category and its second page', (tester) async {
    startApp(app.main);
    await pumpUntil(tester, find.byKey(_home), 'the home page');
    await tester.scrollUntilVisible(
      find.text('Store'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shot(binding, tester, '40_home_store_entry');

    await tester.tap(find.text('Store'));
    await pumpUntil(tester, _inStore(_firstDeal), 'the deals section');
    expect(_inStore('Highlights'), findsOneWidget);
    expect(_inStore('Deals'), findsOneWidget);
    await letArtLoad(tester);
    await shot(binding, tester, '41_store_sections');

    await tester.scrollUntilVisible(
      _inStore('Your cart'),
      300,
      scrollable: _storeScrollable(),
    );
    await letArtLoad(tester, const Duration(seconds: 2));
    await shot(binding, tester, '42_store_lower_sections');
    await tester.scrollUntilVisible(
      _inStore(_firstDeal),
      -300,
      scrollable: _storeScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(_inStore(_firstDeal));
    await pumpUntil(tester, find.byKey(_comicTitle), 'the comic page');
    expect(tester.widget<Text>(find.byKey(_comicTitle)).data, _firstDeal);
    await letArtLoad(tester);
    await shot(binding, tester, '43_comic_from_deal');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, _inStore(_firstDeal), 'the store again');
    expect(find.byKey(_comicTitle), findsNothing);
    await shot(binding, tester, '44_back_to_store');

    await tester.scrollUntilVisible(
      _inStore('Heroes'),
      200,
      scrollable: _storeScrollable(),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(_inStore('Heroes'));
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_categoryGrid),
        matching: find.text(_firstHero),
      ),
      'the heroes category',
    );
    expect(diContainer<RouterRef>().router.state.uri.toString(), '/store');
    await letArtLoad(tester);
    await shot(binding, tester, '45_category_heroes');

    final grid = find
        .descendant(
          of: find.byKey(_categoryGrid),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byKey(_categoryGrid),
        matching: find.text(_twentyFirstHero),
      ),
      400,
      scrollable: grid,
      maxScrolls: 100,
    );
    await letArtLoad(tester);
    expect(find.text(_twentyFirstHero), findsOneWidget);
    await shot(binding, tester, '46_category_page_two');
  });
}
