import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the field does not have the keyboard focus
Future<void> theFieldDoesNotHaveTheKeyboardFocus(WidgetTester tester) async =>
    expect(
      searchFieldFocused(tester),
      isFalse,
      reason: 'the field is not focused',
    );
