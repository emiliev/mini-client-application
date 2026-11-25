import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

/// T-0033-AC4's deep link: `miniclient://app/characters` reaches the list
/// through the file-drop start link (F-0020: `simctl openurl` shows a prompt
/// no script can answer). `main()` reads and deletes the file, then the link
/// takes the same PendingLinks -> GoRouter path as a cold-start link.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0033-AC4 the deep link miniclient://app/characters opens the '
      'list', (tester) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclient://app/characters',
    );

    startApp(app.main);
    await pumpUntil(tester, find.text(first.name), 'the linked character list');

    expect(find.byKey(charactersGridKey), findsOneWidget);
    expect(
      find.byKey(const Key('home.placeholder')),
      findsNothing,
      reason: 'the link, not home, was the start location',
    );
    await letArtLoad(tester);
    await shot(binding, tester, '05_deep_link_characters');
  });
}
