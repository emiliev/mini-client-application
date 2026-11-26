import 'package:flutter_test/flutter_test.dart';

import '../util/discovery_search_env.dart';

/// Usage: the characters section offers {'Show 20'}
///
/// The characters section's header has the action [label], shown whole
/// (not ellipsised).
Future<void> theCharactersSectionOffers(WidgetTester tester, String label) =>
    expectSectionAction(tester, 'character', label);
