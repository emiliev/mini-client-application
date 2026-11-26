import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the field has the keyboard focus
Future<void> theFieldHasTheKeyboardFocus(WidgetTester tester) async =>
    expect(searchFieldFocused(tester), isTrue, reason: 'the field is focused');
