import 'package:flutter_test/flutter_test.dart';

import '../util/comics_details_env.dart';

/// Usage: I tap the creator {'Esme Garrow'}
///
/// Scrolls the credit into view, then taps it.
Future<void> iTapTheCreator(WidgetTester tester, String name) =>
    tapComicTarget(tester, creditRow(name));
