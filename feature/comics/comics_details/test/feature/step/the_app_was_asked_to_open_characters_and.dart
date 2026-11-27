import 'package:comics_details/comics_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/comics_details_env.dart';

/// Usage: the app was asked to open characters {'Amber Vanguard'} and {'Prism Engineer'}
///
/// `openCharacter` for each, once, and nothing else.
Future<void> theAppWasAskedToOpenCharactersAnd(
  WidgetTester tester,
  String first,
  String second,
) async {
  final navigator = comicsNavigator();
  verify(() => navigator.openCharacter(CharacterId(characterNamed(first).id)))
      .called(1);
  verify(() => navigator.openCharacter(CharacterId(characterNamed(second).id)))
      .called(1);
  verifyNoMoreInteractions(navigator);
}
