import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: there is no comics row
///
/// A character nobody features shows its explanation instead of a row of
/// cards.
Future<void> thereIsNoComicsRow(WidgetTester tester) async {
  await scrollCharacterUntilVisible(
    tester,
    find.byKey(characterComicsEmptyKey),
  );
  expect(find.byKey(characterComicsKey), findsNothing);
}
