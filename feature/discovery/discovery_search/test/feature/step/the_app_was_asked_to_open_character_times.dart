import 'package:discovery_search/discovery_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/discovery_search_env.dart';

/// Usage: the app was asked to open character {'Spindle Alchemist'} {2} times
Future<void> theAppWasAskedToOpenCharacterTimes(
  WidgetTester tester,
  String title,
  int times,
) async {
  final navigator = searchNavigator();
  final id = CharacterId(entryTitled('character', title).id);
  verify(() => navigator.openCharacter(id)).called(times);
  verifyNoMoreInteractions(navigator);
}
