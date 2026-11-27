import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the category page of {'heroes'} is open, titled {'Heroes'}
///
/// The flow shows that category's page (flow state, not a route: it opened
/// inside the flow, or the flow opened at it) under that title.
Future<void> theCategoryPageOfIsOpenTitled(
  WidgetTester tester,
  String id,
  String title,
) async {
  await letSectionsLand(tester);
  final state = storeFlowState(tester);
  expect(state.category ?? state.root, id, reason: 'the open category');
  expect(
    tester.widget<Text>(find.byKey(categoryTitleKey)).data,
    title,
    reason: 'the category page title',
  );
}
