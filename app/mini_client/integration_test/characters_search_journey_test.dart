import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mc_e2e_utils/mc_e2e_utils.dart';
import 'package:mc_fixtures_characters/mc_fixtures_characters.dart';
import 'package:mc_mocked_backend/mc_mocked_backend.dart';
import 'package:mini_client/main.dart' as app;

const _field = ValueKey<String>('characters_search.field');
const _results = ValueKey<String>('characters_search.results');
const _profileName = ValueKey<String>('characters_details.name');

/// T-0071-AC5 on a simulator, through the real `main()`: home, Characters,
/// the search action, "amber", the results in name order, a sort chip, a
/// character and its profile; Back to the results, Back to the list.
/// Run through `tool/e2e_ios.sh`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T-0071-AC5 home to Characters, Search, "amber", a sort, a '
      'character and its profile; Back, Back', (tester) async {
    // Fixture facts (seed 42), from the characters fixture's own cast.
    final amber = [
      for (final c in CharacterUniverse(42, defaultMockClock).byName)
        if (c.name.startsWith('Amber')) c,
    ];
    final first = amber.first;
    final lastByName = amber.last;

    startApp(app.main);
    await pumpUntil(
      tester,
      find.byKey(const Key('home.placeholder')),
      'the home page',
    );
    await tester.tap(find.text('Characters'));
    await pumpUntil(
      tester,
      find.byKey(charactersGridKey),
      'the characters list',
    );
    await letArtLoad(tester);
    await shot(binding, tester, '90_characters_list_with_search_action');

    await tester.tap(find.byTooltip('Search characters'));
    await pumpUntil(tester, find.byKey(_field), 'the search page');
    await shot(binding, tester, '91_search_opened');

    await tester.enterText(find.byType(EditableText), 'amber');
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(first.name),
      ),
      'the results for "amber"',
    );
    // The keyboard takes half the screen; with it gone the list shows more.
    FocusManager.instance.primaryFocus?.unfocus();
    await letArtLoad(tester, const Duration(seconds: 1));
    await shot(binding, tester, '92_search_results_name_order');

    await tester.tap(find.text('Name Z–A'));
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(lastByName.name),
      ),
      'the results sorted Z to A, starting with ${lastByName.name}',
    );
    expect(
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(first.name),
      ),
      findsNothing,
      reason: 'the first by name is no longer on the first screen',
    );
    await letArtLoad(tester);
    await shot(binding, tester, '93_search_results_sorted_z_to_a');

    await tester.tap(
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(lastByName.name),
      ),
    );
    await pumpUntil(tester, find.byKey(_profileName), 'the character profile');
    expect(
      tester.widget<Text>(find.byKey(_profileName)).data,
      lastByName.name,
    );
    await letArtLoad(tester);
    await shot(binding, tester, '94_profile_from_search');

    // Back: the search, with the Z-to-A results still showing.
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byKey(_results),
        matching: find.text(lastByName.name),
      ),
      'the search again, below the profile',
    );
    expect(find.byKey(_profileName), findsNothing);
    await shot(binding, tester, '95_back_to_search');

    // Back: the characters list the search was opened from.
    await tester.tap(find.byType(BackButton).first);
    await pumpUntil(
      tester,
      find.byKey(charactersGridKey),
      'the characters list, below the search',
    );
    expect(find.byKey(_field), findsNothing);
    await shot(binding, tester, '96_back_to_list');
  });
}
