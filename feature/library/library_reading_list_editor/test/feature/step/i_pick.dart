import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/reading_list_editor_env.dart';

/// Usage: I pick {'Amber Chronicles #1'}
///
/// Taps the search result with that title (it toggles: a picked comic
/// leaves the list). The results are a lazy list: a row above the viewport
/// is still built (in the cache area, which finders treat as offstage), one
/// further down is scrolled to first. Afterwards the step is scrolled back
/// to its top, where the picked comics show.
Future<void> iPick(WidgetTester tester, String title) async {
  final key = comicRowKey(comicTitled(title).id);
  if (find.byKey(key, skipOffstage: false).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.byKey(key),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(comicResultsKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await tester.pump();
  await tester.tap(find.byKey(key).hitTestable());
  await mcSettle(tester);
  await scrollComicsToTop(tester);
}
