import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: I see the bio of character {100002}
///
/// The fixture character's description, in full, below its section title.
Future<void> iSeeTheBioOfCharacter(WidgetTester tester, int id) async {
  final bio = find.byKey(characterBioKey);
  await scrollCharacterUntilVisible(tester, bio);
  expect(tester.widget<Text>(bio).data, characterWithId(id).description);
}
