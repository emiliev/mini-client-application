import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: I pull the store to refresh
///
/// Back to the top of the store home, then a drag down past the iOS refresh
/// trigger, released; then frames until the refresh control has asked every
/// section to reload (it does so a frame after the release). It does not
/// settle: a held section may still be on its way.
Future<void> iPullTheStoreToRefresh(WidgetTester tester) async {
  await letSectionsLand(tester);
  await scrollStoreToTop(tester);
  await tester.drag(storeBodyScrollable(), const Offset(0, 400));
  await letSectionsLand(tester);
  await letSectionsLand(tester);
}
