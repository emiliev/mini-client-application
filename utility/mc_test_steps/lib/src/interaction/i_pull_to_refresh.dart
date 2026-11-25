import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: I pull to refresh
///
/// Drags the first scrollable on screen down from its top, past the iOS
/// refresh trigger, and lets go; the step ends when the refresh settled.
Future<void> iPullToRefresh(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).hitTestable().first;
  final position = tester.state<ScrollableState>(scrollable).position;
  expect(
    position.pixels,
    position.minScrollExtent,
    reason: 'pull to refresh starts at the top of the list',
  );
  await tester.drag(scrollable, const Offset(0, 400));
  await mcSettle(tester);
}
