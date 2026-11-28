import 'package:characters_search/characters_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_search_env.dart';

/// Usage: the app was asked to open character {'Amber Alchemist'}
///
/// The navigator contract: `openCharacter` with [name]'s id (from the
/// fixture cast), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenCharacter(
  WidgetTester tester,
  String name,
) async {
  final navigator = searchNavigator();
  verify(
    () => navigator.openCharacter(CharacterId(characterNamed(name).id)),
  ).called(1);
  verifyNoMoreInteractions(navigator);
}
