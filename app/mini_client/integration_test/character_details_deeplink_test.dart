import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mini_client/main.dart' as app;

/// T-0049-AC1's cold link to a character: `miniclient://app/characters/100366`
/// opens `[home, characters, details]` through the file-drop start link
/// (F-0020). The first screen has a back button; Back leads to the list, and
/// Back from the list to home.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0049-AC1 the cold link miniclient://app/characters/100366 '
      'has a back stack: details, the list, home', (tester) async {
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/characters/100366',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('character.details.placeholder')),
      'the linked character details',
    );
    expect(find.byType(BackButton), findsWidgets, reason: 'a back button');
    expect(find.byKey(const Key('home.placeholder')), findsNothing);
    await shot(binding, tester, '55_deep_link_character_details');

    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('characters_list.grid')),
      'the characters list, below the details',
    );
    await letArtLoad(tester);
    await shot(binding, tester, '55b_back_from_details_is_list');

    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'home, below the list',
    );
    await shot(binding, tester, '55c_back_from_list_is_home');
  });
}
