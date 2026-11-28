// BDD for every archetype: `.feature` files from the spec's `bdd` (plan 05
// section 3, ADR-0017) and bdd_widget_test's step naming, plus the table of
// the shared steps in `mc_test_steps` (checked against its barrel by
// test/bdd_test.dart), so an archetype knows which steps it must provide.

import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/core/spec/spec.dart';

/// The step files `mc_test_steps` exports (its `:step_index`): a feature's
/// own step with one of these names is a build error, and one of these
/// needs no step file in the feature.
const sharedSteps = {
  'errors_were_reported',
  'i_am_signed_in_as',
  'i_cancel_the_dialog',
  'i_choose_in_the_sheet',
  'i_confirm_the_dialog',
  'i_dont_see',
  'i_press_search_on_the_keyboard',
  'i_pull_to_refresh',
  'i_see',
  'i_see_the_texts',
  'i_swipe_back',
  'i_tap',
  'i_tap_the_icon_button',
  'i_tap_twice_in_quick_succession',
  'i_type',
  'i_type_one_character_at_a_time',
  'milliseconds_pass',
  'no_analytics_event_was_tracked',
  'no_error_was_reported',
  'nothing_overflows',
  'signs_in_just_before_the_app_sends',
  'the_analytics_event_was_tracked',
  'the_analytics_event_was_tracked_with',
  'the_app_can_no_longer_write_to_storage',
  'the_app_finishes_writing_to_storage',
  'the_app_finishes_writing_to_storage_never_showing',
  'the_app_sends',
  'the_backend_answered_with',
  'the_backend_fails_with',
  'the_backend_fails_with_once',
  'the_backend_holds',
  'the_backend_holds_the_next',
  'the_backend_received',
  'the_backend_received_requests_for',
  'the_backend_received_with_a_token_of',
  'the_backend_received_with_the_bearer_of',
  'the_backend_received_with_the_body',
  'the_backend_recovers',
  'the_backend_releases',
  'the_backend_runs_the_scenario',
  'the_backend_serves',
  'the_button_is_disabled',
  'the_device_locale_is',
  'the_field_reads',
  'the_flag_is',
  'the_pseudolocale_is_active',
  'the_screen_was_tracked',
  'the_screens_tracked_are',
  'the_session_belongs_to',
  'the_text_scale_is',
  'the_toast_is_shown',
};

final _keyword = RegExp(r'^(Given|When|Then|And|But)\s+');
final _param = RegExp(r'\{[^}]*\}');

/// A step line without its Gherkin keyword.
String stepText(String line) => line.replaceFirst(_keyword, '');

/// bdd_widget_test's file name for a step: its words without parameters
/// and punctuation, lower case, joined with `_` (F-0031 fact 3: hyphens and
/// apostrophes drop, so `don't` is `dont`).
String stepFileName(String line) =>
    stepText(line)
        .replaceAll(_param, ' ')
        .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.toLowerCase())
        .join('_');

/// The step's function name: [stepFileName] in camelCase.
String stepFunctionName(String line) => camelCase(stepFileName(line));

/// The step's parameter literals, in order (`{'Amber'}` -> `'Amber'`).
List<String> stepParams(String line) => [
  for (final m in _param.allMatches(stepText(line)))
    m[0]!.substring(1, m[0]!.length - 1),
];

/// Every step line of [features], in file order: backgrounds, then each
/// scenario's steps, then each outline's.
Iterable<String> allSteps(List<BddFeatureSpec> features) sync* {
  for (final f in features) {
    yield* f.backgroundSteps;
    for (final s in f.scenarios) {
      yield* s.steps;
    }
    for (final o in f.outlines) {
      yield* o.steps;
    }
  }
}

/// A rule example's value as an Examples cell: strings as Dart string
/// literals (steps write `{<column>}`), everything else as written.
String _cell(Object? v) => v is String ? dartString(v) : '$v';

/// The Examples table of a rule-driven outline (R6): one column per key of
/// the rule's examples, in first-seen order, one row per example.
List<List<String>> outlineExamples(RuleSpec rule) {
  final columns = <String>[];
  for (final e in rule.examples) {
    for (final k in e.keys) {
      if (!columns.contains(k)) columns.add(k);
    }
  }
  return [
    columns,
    for (final e in rule.examples) [for (final c in columns) _cell(e[c])],
  ];
}

/// The feature file of [f]: `Feature:`, its description, the Background,
/// then each scenario with its tags (the id first) and Examples table, then
/// each outline, whose Examples are its rule's examples ([rules] by id).
String renderFeature(
  BddFeatureSpec f, {
  Map<String, RuleSpec> rules = const {},
}) {
  final b = StringBuffer()
    ..writeln(
      'Feature: ${f.title ?? pascalCase(f.feature).replaceAllMapped(RegExp('(?<=[a-z])([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}')}',
    );
  if (f.description case final d?) {
    for (final l in d.trimRight().split('\n')) {
      b.writeln(l.isEmpty ? '' : '  $l');
    }
  }
  if (f.backgroundSteps.isNotEmpty) {
    b
      ..writeln()
      ..writeln('  Background:');
    for (final s in f.backgroundSteps) {
      b.writeln('    $s');
    }
  }
  void scenario(
    String? id,
    List<String> tagList,
    String title,
    List<String> steps,
    List<List<String>> examples,
  ) {
    b.writeln();
    final tags = [?id, ...tagList].map((t) => t.startsWith('@') ? t : '@$t');
    if (tags.isNotEmpty) b.writeln('  ${tags.join(' ')}');
    b.writeln(
      '  ${examples.isEmpty ? 'Scenario' : 'Scenario Outline'}: $title',
    );
    for (final step in steps) {
      b.writeln('    $step');
    }
    if (examples.isNotEmpty) {
      final widths = [
        for (var c = 0; c < examples.first.length; c++)
          examples.map((r) => r[c].length).reduce((a, b) => a > b ? a : b),
      ];
      b
        ..writeln()
        ..writeln('    Examples:');
      for (final row in examples) {
        b.writeln(
          '      | ${[for (final (c, cell) in row.indexed) cell.padRight(widths[c])].join(' | ')} |',
        );
      }
    }
  }

  for (final s in f.scenarios) {
    scenario(s.id, s.tags, s.title, s.steps, s.examples);
  }
  for (final o in f.outlines) {
    final rule = rules[o.rule];
    if (rule == null || o.steps.isEmpty || rule.examples.isEmpty) {
      throw StateError(
        '${o.path}: outline "${o.id}" needs steps and rule "${o.rule}" with examples',
      );
    }
    scenario(o.id, o.tags, o.title, o.steps, outlineExamples(rule));
  }
  return b.toString();
}
