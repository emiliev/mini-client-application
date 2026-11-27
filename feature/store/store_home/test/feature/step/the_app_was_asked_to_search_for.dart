import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the app was asked to search for {'amber'}
///
/// `openSearch` was called once in all, with exactly that query.
Future<void> theAppWasAskedToSearchFor(
  WidgetTester tester,
  String query,
) async => expect(
  navigatorCalls().where((c) => c.startsWith('search ')),
  ['search $query'],
  reason: 'searches asked for',
);
