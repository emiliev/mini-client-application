import 'package:comics_details/comics_details.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I open comic {501500} on two pages
///
/// Two flows of the same comic, one above the other (as two tabs or two
/// stacked routes would hold them), each with its own scope and blocs, over
/// one app root: one session, one bus, one backend.
Future<void> iOpenComicOnTwoPages(WidgetTester tester, int id) async {
  await ensureComicsContainer();
  Widget page(int n) => Expanded(
    child: KeyedSubtree(
      key: comicPageKey(n),
      child: ComicsDetailsFlow(
        navigator: comicsNavigator(),
        comicId: ComicId(id),
      ),
    ),
  );
  await initFlow(
    tester,
    () => comicsTestHost(Column(children: [page(1), page(2)])),
  );
  await mcSettle(tester);
}
