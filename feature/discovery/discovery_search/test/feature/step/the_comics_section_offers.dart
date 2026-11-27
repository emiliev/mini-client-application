import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the comics section offers {'Show 20'}
///
/// The comics section's header has the action [label], shown whole (not
/// ellipsised).
Future<void> theComicsSectionOffers(WidgetTester tester, String label) =>
    expectSectionAction(tester, 'comic', label);
