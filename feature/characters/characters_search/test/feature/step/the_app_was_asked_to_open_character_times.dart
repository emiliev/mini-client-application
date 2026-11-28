import 'package:characters_search/characters_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_search_env.dart';

/// Usage: the app was asked to open character {'Amber Alchemist'} {2} times
///
/// The navigator contract: `openCharacter` with [name]'s id, [times] times,
/// and nothing else.
Future<void> theAppWasAskedToOpenCharacterTimes(
  WidgetTester tester,
  String name,
  int times,
) async {
  final navigator = searchNavigator();
  verify(
    () => navigator.openCharacter(CharacterId(characterNamed(name).id)),
  ).called(times);
  verifyNoMoreInteractions(navigator);
}
