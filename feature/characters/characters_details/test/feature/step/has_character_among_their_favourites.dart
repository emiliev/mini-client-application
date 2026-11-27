import 'package:flutter_test/flutter_test.dart';

import '../util/favourites_probe.dart';

/// Usage: {'reader@mini-client.test'} has character {501500} among their favourites
///
/// Seeds the backend before the page opens, as another device would have.
Future<void> hasCharacterAmongTheirFavourites(
  WidgetTester tester,
  String email,
  int character,
) async {
  final response = await favouritesProbe(tester, email, 'PUT', character);
  expect(response.statusCode, 200, reason: 'seeded character $character');
}
