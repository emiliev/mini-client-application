import 'package:flutter_test/flutter_test.dart';

import '../util/characters_list_env.dart';

/// Usage: the characters list shows {60} characters
///
/// The grid's item count: every loaded character, on screen or not.
Future<void> theCharactersListShowsCharacters(
  WidgetTester tester,
  int count,
) async => expect(charactersShown(tester), count);
