import 'package:flutter_test/flutter_test.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: {'reader@mini-client.test'} has a list of {100} comics
///
/// Seeds the backend directly (not through the app): a private list named
/// "Big" holding the first [count] comic ids (`500000` on). In the default
/// set it is `l-5`.
Future<void> hasAListOfComics(
  WidgetTester tester,
  String email,
  int count,
) async {
  final response = await libraryProbe(
    tester,
    email,
    'POST',
    '/v1/me/lists',
    body: {
      'name': 'Big',
      'visibility': 'private',
      'comicIds': [for (var i = 0; i < count; i++) 500000 + i],
    },
  );
  expect(response.statusCode, 201, reason: 'the list was seeded');
}
