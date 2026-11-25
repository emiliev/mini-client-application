import 'package:characters_list/characters_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_list_env.dart';

/// Usage: the app was asked to open character {'Amber Alchemist'}
///
/// The navigator contract: `openCharacter` with [name]'s id, exactly once,
/// and nothing else.
Future<void> theAppWasAskedToOpenCharacter(
  WidgetTester tester,
  String name,
) async {
  final navigator = charactersNavigator();
  final id = CharacterId(characterNamed(name).id);
  verify(() => navigator.openCharacter(id)).called(1);
  verifyNoMoreInteractions(navigator);
}
