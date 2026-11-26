import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the chip {'All'} is not selected
Future<void> theChipIsNotSelected(WidgetTester tester, String label) async =>
    expect(
      chipSelected(tester, label),
      isFalse,
      reason: '"$label" not selected',
    );
