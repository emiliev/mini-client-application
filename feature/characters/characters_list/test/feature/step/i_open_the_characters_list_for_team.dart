import 'package:characters_list/characters_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/characters_list_env.dart';

/// Usage: I open the characters list for team {'harbor-watch'}
///
/// Enters the feature the way the route `/characters` with a team does: the
/// flow's `initialTeamId` is the team's id (CONTRACT.md of
/// `mc_fixtures_characters`).
Future<void> iOpenTheCharactersListForTeam(
  WidgetTester tester,
  String teamId,
) async {
  await initFlow(
    tester,
    () => charactersTestHost(
      CharactersListFlow(
        navigator: charactersNavigator(),
        initialTeamId: teamId,
      ),
    ),
  );
  await mcSettle(tester);
}
