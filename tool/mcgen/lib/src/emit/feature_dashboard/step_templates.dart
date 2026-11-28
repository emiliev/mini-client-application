// The BDD step files a dashboard has a template for: the steps that read only
// the test env's fixed names (opening the page, a section's states, its
// retry, taps, the analytics counts). Generated once from the store_home
// exemplar by swapping its nouns for `<<placeholders>>` and maintained by
// hand (F-0072 section 3.1). The env (owned) is where a module's fixtures and
// finders live; a step file is the same for every dashboard.
//
// A key is the step's file name, with the page noun as `{page}` and the
// analytics prefix as `{k}`. A step with no template is a failing owned stub.

const Map<String, String> stepTemplates = {
  'every_section_but_is_ready': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';
import 'the_section_is_ready.dart';

/// Usage: <<usage>>
Future<void> <<fn>>(WidgetTester tester, String section) async {
  for (final other in <<kc>>Sections.where((s) => s != section)) {
    await theSectionIsReady(tester, other);
  }
}
''',
  'every_section_but_shows_its_error': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';
import 'the_section_shows_its_error_with_retry.dart';

/// Usage: <<usage>>
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
) async {
  for (final other in <<kc>>Sections.where((s) => s != section)) {
    await theSectionShowsItsErrorWithRetry(tester, other);
  }
}
''',
  'i_leave_the_{page}': r'''
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: <<usage>>
///
/// The flow is removed from the tree, so its pages and blocs are disposed
/// (the user left the <<page>>).
Future<void> <<fn>>(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}
''',
  'i_open_a_dialog_over_the_{page}_and_close_it': r'''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
Future<void> <<fn>>(WidgetTester tester) async {
  await letSectionsLand(tester);
  final context = tester.element(find.byKey(<<body_key>>));
  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const AlertDialog(content: Text('probe dialog')),
    ),
  );
  await mcSettle(tester);
  expect(find.text('probe dialog'), findsOneWidget);
  Navigator.of(tester.element(find.text('probe dialog'))).pop();
  await mcSettle(tester);
  await letSectionsLand(tester);
}
''',
  'i_open_the_{page}': r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Enters the feature the way the app does: through its flow (barrel only),
/// with the navigator <<and_clock>>passed in the constructor.
Future<void> <<fn>>(WidgetTester tester) async {
  await ensure<<K>>Container();
  await initFlow(tester, () => <<kc>>TestHost(<<kc>>FlowUnderTest()));
  await mcSettle(tester);
}
''',
  'i_pull_the_{page}_to_refresh': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Back to the top of the <<page>> home, then a drag down past the iOS refresh
/// trigger, released; then frames until the refresh control has asked every
/// section to reload (it does so a frame after the release). It does not
/// settle: a held section may still be on its way.
Future<void> <<fn>>(WidgetTester tester) async {
  await letSectionsLand(tester);
  await scroll<<K>>ToTop(tester);
  await tester.drag(<<kc>>BodyScrollable(), const Offset(0, 400));
  await letSectionsLand(tester);
  await letSectionsLand(tester);
}
''',
  'i_tap_in_the_section': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Scrolls to the item inside that section (a carousel is scrolled
/// sideways) and taps it.
Future<void> <<fn>>(
  WidgetTester tester,
  String text,
  String section,
) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(text));
}
''',
  'i_tap_in_the_section_and_again_after_milliseconds': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Two taps [milliseconds] of fake time apart: just inside or just outside
/// the open guard.
Future<void> <<fn>>(
  WidgetTester tester,
  String text,
  String section,
  int milliseconds,
) async {
  await letSectionsLand(tester);
  await tapIn(
    tester,
    section,
    find.text(text),
    times: 2,
    between: Duration(milliseconds: milliseconds),
  );
}
''',
  'i_tap_in_the_section_twice_in_quick_succession': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Two taps within one frame: both reach the widget, so both events reach
/// its bloc.
Future<void> <<fn>>(
  WidgetTester tester,
  String text,
  String section,
) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(text), times: 2);
}
''',
  'i_tap_retry_in_the_section': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Taps the Retry of that section's own error card.
Future<void> <<fn>>(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(retryLabel(tester)));
}
''',
  'i_tap_retry_in_the_section_twice_in_quick_succession': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Two taps on that section's Retry within one frame: both reach the bloc.
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
) async {
  await letSectionsLand(tester);
  await tapIn(tester, section, find.text(retryLabel(tester)), times: 2);
}
''',
  'only_the_section_shows_an_error': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';
import 'the_section_is_ready.dart';
import 'the_section_shows_its_error_with_retry.dart';

/// Usage: <<usage>>
///
/// That section shows its own error card with Retry, and every other
/// section of the <<page>> is ready (P1-21 AC6).
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
) async {
  await theSectionShowsItsErrorWithRetry(tester, section);
  for (final other in <<kc>>Sections.where((s) => s != section)) {
    await theSectionIsReady(tester, other);
  }
}
''',
  'the_section_is_announced_as': r'''
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// While the section loads, a screen reader hears exactly [label] for its
/// skeleton.
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
  String label,
) async {
  await letSectionsLand(tester);
  final skeleton = find.byKey(sectionPartKey(section, 'skeleton'));
  await scroll<<K>>UntilVisible(tester, skeleton);
  expect(
    tester.widget<Semantics>(skeleton).properties.label,
    label,
    reason: 'the $section skeleton announcement',
  );
}
''',
  'the_section_is_loading': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// The section shows its own skeleton, and neither content nor error.
Future<void> <<fn>>(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  final skeleton = find.byKey(sectionPartKey(section, 'skeleton'));
  await scroll<<K>>UntilVisible(tester, skeleton);
  expect(skeleton, findsOneWidget, reason: 'the $section skeleton');
  for (final part in ['content', 'error', 'empty']) {
    expect(find.byKey(sectionPartKey(section, part)), findsNothing);
  }
}
''',
  'the_section_is_ready': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// The section shows its content, and neither its skeleton nor its error.
Future<void> <<fn>>(WidgetTester tester, String section) async {
  await letSectionsLand(tester);
  final content = find.byKey(sectionPartKey(section, 'content'));
  await scroll<<K>>UntilVisible(tester, content);
  expect(content, findsOneWidget, reason: 'the $section content');
  for (final part in ['error', 'skeleton', 'empty']) {
    expect(
      find.byKey(sectionPartKey(section, part)),
      findsNothing,
      reason: 'the $section section is not $part',
    );
  }
}
''',
  'the_section_shows': r'''
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// [text] is inside that section (non-breaking spaces read as plain ones).
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
  String text,
) async {
  await letSectionsLand(tester);
  await scrollToSection(tester, section);
  final match = find.descendant(
    of: find.byKey(sectionKey(section)),
    matching: find.byWidgetPredicate(
      (w) => w is Text && plainSpaces(w.data ?? '') == plainSpaces(text),
    ),
  );
  if (match.evaluate().isEmpty) {
    await scroll<<K>>UntilVisible(tester, match);
  }
  expect(match, findsWidgets, reason: 'the $section section shows "$text"');
}
''',
  'the_section_shows_its_error_with_retry': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// The section's own error card, with a Retry button, and none of its
/// content or skeleton.
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
) async {
  await letSectionsLand(tester);
  final error = find.byKey(sectionPartKey(section, 'error'));
  await scroll<<K>>UntilVisible(tester, error);
  expect(error, findsOneWidget, reason: 'the $section error card');
  await tester.ensureVisible(error);
  await tester.pump();
  expect(
    find.descendant(of: error, matching: find.text(retryLabel(tester))),
    findsOneWidget,
    reason: 'the $section error card has Retry',
  );
  for (final part in ['content', 'skeleton']) {
    expect(find.byKey(sectionPartKey(section, part)), findsNothing);
  }
}
''',
  'the_section_was_viewed_times': r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// Exactly [count] `store_section_viewed` events with that `section` reached
/// the analytics sink (0: none). The generic analytics steps check that an
/// event was tracked; this one also counts, so "once per visit" and "not for
/// a failed section" are pinned.
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
  int count,
) async {
  await letSectionsLand(tester);
  expect(<<kc>>Sections, contains(section));
  final views = McTestSession.current.analytics.events.where(
    (e) => e.name == '<<viewed_event>>' && e.params['section'] == section,
  );
  expect(views, hasLength(count), reason: '$section viewed');
}
''',
  'the_sections_are': r'''
import 'package:flutter_test/flutter_test.dart';

import '../util/<<module>>_env.dart';

/// Usage: <<usage>>
///
/// The section headers from the top of the <<page>> to its end are exactly
/// these, in this order.
Future<void> <<fn>>(WidgetTester tester, String titles) async {
  await letSectionsLand(tester);
  expect(
    await sectionTitlesInOrder(tester),
    [for (final t in titles.split(',')) t.trim()],
    reason: 'the sections, top to bottom',
  );
}
''',
  'the_{k}_tap_was_tracked_with_section_kind_and_id': r'''
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_test_steps/mc_test_steps.dart';

/// Usage: <<usage>>
///
/// `store_item_tapped` with exactly these params, through the generic
/// T-0053 step (`the analytics event {name} was tracked with`); this step
/// only builds its table, so a Scenario Outline can fill it.
Future<void> <<fn>>(
  WidgetTester tester,
  String section,
  String kind,
  String id,
) => theAnalyticsEventWasTrackedWith(
  tester,
  '<<tapped_event>>',
  DataTable([
    const ['key', 'json'],
    ['section', '"$section"'],
    ['kind', '"$kind"'],
    ['id', '"$id"'],
  ]),
);
''',
};
