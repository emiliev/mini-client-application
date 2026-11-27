import 'package:flutter_test/flutter_test.dart';

import '../util/favourites_probe.dart';

/// Usage: character {501500} is a favourite of {'reader@mini-client.test'}
///
/// The backend holds the favourite for that user: the write reached the
/// identity domain under their bearer.
Future<void> characterIsAFavouriteOf(
  WidgetTester tester,
  int character,
  String email,
) async {
  final response = await favouritesProbe(tester, email, 'GET', character);
  expect(
    response.statusCode,
    200,
    reason: 'character $character is a favourite',
  );
}
