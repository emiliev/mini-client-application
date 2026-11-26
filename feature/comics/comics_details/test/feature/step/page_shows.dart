import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: page {1} shows {'Remove from favourites'}
///
/// The text is on that page (`I open comic {id} on two pages`).
Future<void> pageShows(WidgetTester tester, int page, String text) async =>
    expect(
      find.descendant(
        of: find.byKey(comicPageKey(page)),
        matching: find.text(text),
      ),
      findsOneWidget,
      reason: 'page $page shows "$text"',
    );
