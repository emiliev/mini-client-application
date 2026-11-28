import 'package:flutter_test/flutter_test.dart';

import '../util/characters_search_env.dart';

/// Usage: I tap the sort chip {'Name Z–A'}
///
/// Taps the sort chip [label], scrolling the chips until it is on screen.
Future<void> iTapTheSortChip(WidgetTester tester, String label) =>
    tapChip(tester, searchSortKey, label);
