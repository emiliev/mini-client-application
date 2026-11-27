import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

const _home = Key('home.placeholder');
const _storeBody = ValueKey<String>('store_home.body');
const _categoryGrid = ValueKey<String>('store_category.grid');
const _categoryTitle = ValueKey<String>('store_category.title');

/// T-0056-AC5's second deep link: `miniclient://app/store/categories/heroes`
/// cold opens the category over the store over home; Back walks that nested
/// path: the store, then home (T-0049).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0056-AC5 the cold link to a category opens it, and Back '
      'walks to the store and then home', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/store/categories/heroes',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_categoryGrid),
        matching: find.text('Ember Chronicles #1'),
      ),
      'the linked category',
    );
    await pumpUntil(tester, find.text('Heroes'), 'the category title');
    expect(tester.widget<Text>(find.byKey(_categoryTitle)).data, 'Heroes');
    expect(find.byKey(_home), findsNothing, reason: 'the link was the start');
    await letArtLoad(tester);
    await shot(binding, tester, '48_deep_link_category');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_storeBody), 'the store, after Back');
    await letArtLoad(tester, const Duration(seconds: 2));
    await shot(binding, tester, '48b_back_from_category_is_store');

    await tester.tap(find.byType(BackButton).last);
    await pumpUntil(tester, find.byKey(_home), 'home, after Back again');
    await shot(binding, tester, '48c_back_from_store_is_home');
  });
}
