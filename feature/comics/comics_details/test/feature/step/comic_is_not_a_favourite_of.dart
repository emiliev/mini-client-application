import 'package:flutter_test/flutter_test.dart';

import '../util/favourites_probe.dart';

/// Usage: comic {501500} is not a favourite of {'reader@mini-client.test'}
///
/// The backend holds no such favourite for that user (`404 not_favourite`).
Future<void> comicIsNotAFavouriteOf(
  WidgetTester tester,
  int comic,
  String email,
) async {
  final response = await favouritesProbe(tester, email, 'GET', comic);
  expect(response.statusCode, 404, reason: 'comic $comic is not a favourite');
}
