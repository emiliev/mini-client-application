import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/comics_details_env.dart';

/// Usage: I open comic {501500}
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator passed in the constructor [tide-nav §3.1].
Future<void> iOpenComic(WidgetTester tester, int id) async {
  await ensureComicsContainer();
  await initFlow(tester, () => comicsTestHost(comicsDetailsFlowUnderTest(id)));
  await mcSettle(tester);
}
