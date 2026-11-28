import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../util/characters_list_env.dart';

/// Usage: the app was asked to open the search
///
/// The navigator contract: `openSearch` exactly once, and nothing else.
Future<void> theAppWasAskedToOpenTheSearch(WidgetTester tester) async {
  final navigator = charactersNavigator();
  verify(navigator.openSearch).called(1);
  verifyNoMoreInteractions(navigator);
}
