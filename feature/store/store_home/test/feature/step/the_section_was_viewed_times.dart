import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/store_home_env.dart';

/// Usage: the section {'deals'} was viewed {1} times
///
/// Exactly [count] `store_section_viewed` events with that `section` reached
/// the analytics sink (0: none). The generic analytics steps check that an
/// event was tracked; this one also counts, so "once per visit" and "not for
/// a failed section" are pinned.
Future<void> theSectionWasViewedTimes(
  WidgetTester tester,
  String section,
  int count,
) async {
  await letSectionsLand(tester);
  expect(storeSections, contains(section));
  final views = McTestSession.current.analytics.events.where(
    (e) => e.name == 'store_section_viewed' && e.params['section'] == section,
  );
  expect(views, hasLength(count), reason: '$section viewed');
}
