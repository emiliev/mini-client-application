import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/store_home_env.dart';

/// Usage: the {'deals'} section is announced as {'Wird geladen: Angebote'}
///
/// While the section loads, a screen reader hears exactly [label] for its
/// skeleton.
Future<void> theSectionIsAnnouncedAs(
  WidgetTester tester,
  String section,
  String label,
) async {
  await letSectionsLand(tester);
  final skeleton = find.byKey(sectionPartKey(section, 'skeleton'));
  await scrollStoreUntilVisible(tester, skeleton);
  expect(
    tester.widget<Semantics>(skeleton).properties.label,
    label,
    reason: 'the $section skeleton announcement',
  );
}
