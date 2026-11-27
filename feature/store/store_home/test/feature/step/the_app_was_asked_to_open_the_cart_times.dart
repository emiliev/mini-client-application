import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the app was asked to open the cart {1} times
Future<void> theAppWasAskedToOpenTheCartTimes(
  WidgetTester tester,
  int count,
) async => expect(
  navigatorCalls().where((c) => c == 'cart'),
  hasLength(count),
  reason: 'the cart opened',
);
