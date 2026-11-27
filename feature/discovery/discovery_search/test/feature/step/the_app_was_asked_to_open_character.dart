import 'package:discovery_search/discovery_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/discovery_search_env.dart';

/// Usage: the app was asked to open character {'Spindle Alchemist'}
///
/// The navigator contract: `openCharacter` with [title]'s id (from the
/// fixture index), exactly once, and nothing else.
Future<void> theAppWasAskedToOpenCharacter(
  WidgetTester tester,
  String title,
) async {
  final navigator = searchNavigator();
  final id = CharacterId(entryTitled('character', title).id);
  verify(() => navigator.openCharacter(id)).called(1);
  verifyNoMoreInteractions(navigator);
}
