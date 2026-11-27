import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the app was asked to open comic {501501} {1} times, then comic {502240}
///
/// The comics opened, in order, are exactly [first] [count] times and then
/// [then] once: another item goes through at once, even inside the guard.
Future<void> theAppWasAskedToOpenComicTimesThenComic(
  WidgetTester tester,
  int first,
  int count,
  int then,
) async => expect(
  navigatorCalls().where((c) => c.startsWith('comic ')),
  [...List.filled(count, 'comic $first'), 'comic $then'],
  reason: 'comics opened, in order',
);
