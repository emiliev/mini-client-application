import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

/// Usage: the store tap was tracked with section {'deals'}, kind {'comic'} and id {'501501'}
///
/// `store_item_tapped` with exactly these params, through the generic
/// T-0053 step (`the analytics event {name} was tracked with`); this step
/// only builds its table, so a Scenario Outline can fill it.
Future<void> theStoreTapWasTrackedWithSectionKindAndId(
  WidgetTester tester,
  String section,
  String kind,
  String id,
) => theAnalyticsEventWasTrackedWith(
  tester,
  'store_item_tapped',
  DataTable([
    const ['key', 'json'],
    ['section', '"$section"'],
    ['kind', '"$kind"'],
    ['id', '"$id"'],
  ]),
);
