import 'package:comics_details/comics_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/comics_details_env.dart';

/// Usage: the app was asked to open character {'Amber Vanguard'}
///
/// The navigator contract: `openCharacter` with [name]'s id (from the
/// characters fixture), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenCharacter(
  WidgetTester tester,
  String name,
) async {
  final navigator = comicsNavigator();
  final id = CharacterId(characterNamed(name).id);
  verify(() => navigator.openCharacter(id)).called(1);
  verifyNoMoreInteractions(navigator);
}
