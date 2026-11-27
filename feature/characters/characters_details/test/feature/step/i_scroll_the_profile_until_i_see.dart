import 'package:flutter_test/flutter_test.dart';

import '../util/characters_details_env.dart';

/// Usage: I scroll the profile until I see {'Comics'}
///
/// Real drags of the profile page until [text] is on screen.
Future<void> iScrollTheProfileUntilISee(WidgetTester tester, String text) =>
    scrollCharacterUntilVisible(tester, find.text(text));
