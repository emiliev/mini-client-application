import 'package:flutter_test/flutter_test.dart';

import '../util/favourites_probe.dart';

/// Usage: character {501500} is not a favourite of {'reader@mini-client.test'}
///
/// The backend holds no such favourite for that user (`404 not_favourite`).
Future<void> characterIsNotAFavouriteOf(
  WidgetTester tester,
  int character,
  String email,
) async {
  final response = await favouritesProbe(tester, email, 'GET', character);
  expect(
    response.statusCode,
    404,
    reason: 'character $character is not a favourite',
  );
}
