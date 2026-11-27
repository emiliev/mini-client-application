import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/store_home_env.dart';

/// Usage: I tap {'Gale Chronicles #1'} on the category page
Future<void> iTapOnTheCategoryPage(WidgetTester tester, String title) async {
  final grid = find.byKey(categoryGridKey);
  final scrollable = find
      .descendant(of: grid, matching: find.byType(Scrollable))
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  final target = find.descendant(of: grid, matching: find.text(title));
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target.hitTestable());
  await mcSettle(tester);
}
