import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I scroll the comic until I see {'Characters'}
///
/// Real drags of the details page until [text] is on screen.
Future<void> iScrollTheComicUntilISee(WidgetTester tester, String text) =>
    scrollComicUntilVisible(tester, find.text(text));
