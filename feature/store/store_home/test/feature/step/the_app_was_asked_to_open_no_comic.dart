import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the app was asked to open no comic
Future<void> theAppWasAskedToOpenNoComic(WidgetTester tester) async => expect(
  navigatorCalls().where((c) => c.startsWith('comic ')),
  isEmpty,
  reason: 'no comic opened',
);
