import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I pick {'Amber Chronicles #1'}
///
/// Taps the search result with that title (it toggles: a picked comic
/// leaves the list).
Future<void> iPick(WidgetTester tester, String title) async {
  final row = find.byKey(comicRowKey(comicTitled(title).id));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row.hitTestable());
  await mcSettle(tester);
}
