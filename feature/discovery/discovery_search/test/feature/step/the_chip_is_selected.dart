import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the chip {'Comics'} is selected
Future<void> theChipIsSelected(WidgetTester tester, String label) async =>
    expect(chipSelected(tester, label), isTrue, reason: '"$label" selected');
