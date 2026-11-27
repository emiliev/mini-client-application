import 'dart:io';

import 'package:app_core/app_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:universe_sandbox/main.dart' as app;

/// T-0033-AC3: the sandbox takes a start link through the same file-drop hook
/// as mini_client (F-0020), in its own scheme, so e2e can drive its links.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0033-AC3 a sandbox start link opens that character on the '
      'simulator', (tester) async {
    final first = CharacterUniverse(42, defaultMockClock).byName.first;
    File('${Directory.systemTemp.path}/$e2eStartLinkFile').writeAsStringSync(
      'miniclientuniverse://app/characters/${first.id}',
    );

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const ValueKey<String>('characters_details.name')),
      'the linked character profile',
    );

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('characters_details.name')),
          )
          .data,
      first.name,
    );
    await shot(binding, tester, '02_sandbox_start_link');
  });
}
