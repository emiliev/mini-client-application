import 'package:flutter_test/flutter_test.dart';

import '../util/favourites_probe.dart';

/// Usage: comic {501500} is a favourite of {'reader@mini-client.test'}
///
/// The backend holds the favourite for that user: the write reached the
/// identity domain under their bearer.
Future<void> comicIsAFavouriteOf(
  WidgetTester tester,
  int comic,
  String email,
) async {
  final response = await favouritesProbe(tester, email, 'GET', comic);
  expect(response.statusCode, 200, reason: 'comic $comic is a favourite');
}
