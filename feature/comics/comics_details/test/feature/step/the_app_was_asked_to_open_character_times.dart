import 'package:comics_details/comics_details.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/comics_details_env.dart';

/// Usage: the app was asked to open character {'Amber Vanguard'} {2} times
Future<void> theAppWasAskedToOpenCharacterTimes(
  WidgetTester tester,
  String name,
  int times,
) async {
  final navigator = comicsNavigator();
  final id = CharacterId(characterNamed(name).id);
  verify(() => navigator.openCharacter(id)).called(times);
  verifyNoMoreInteractions(navigator);
}
