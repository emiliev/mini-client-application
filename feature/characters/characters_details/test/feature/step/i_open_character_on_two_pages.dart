import 'package:characters_details/characters_details.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_details_env.dart';

/// Usage: I open character {501500} on two pages
///
/// Two flows of the same character, one above the other (as two tabs or two
/// stacked routes would hold them), each with its own scope and blocs, over
/// one app root: one session, one bus, one backend.
Future<void> iOpenCharacterOnTwoPages(WidgetTester tester, int id) async {
  await ensureCharactersContainer();
  Widget page(int n) => Expanded(
    child: KeyedSubtree(
      key: characterPageKey(n),
      child: CharacterDetailsFlow(
        navigator: charactersNavigator(),
        characterId: CharacterId(id),
      ),
    ),
  );
  await initFlow(
    tester,
    () => charactersTestHost(Column(children: [page(1), page(2)])),
  );
  await mcSettle(tester);
}
