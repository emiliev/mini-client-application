# F-0012: `bazel test` analyzes and format-checks only the test target, never its libraries

- **Date:** 2026-11-23
- **Author:** crew: Verifier (T-0014)
- **Type:** Gotcha
- **Related:** T-0014-AC2, plan 03 §1.4 (".bazelrc: Analysis + format under test"), plan 05 (test gates), [verification report](../evidence/T-0014/verification-report.md)

## Summary
`.bazelrc` sets `test --aspects=@rules_dart//dart:analyze.bzl%dart_analyze` and `test --output_groups=+dart_analyze,+dart_format`. Bazel collects output groups only from **top-level** targets, so `tool/bazelw test //spike/hello:widget_test` runs exactly **one** DartAnalyze and **one** DartFormat action, both on `//spike/hello:widget_test` (counted in the T-0014 Verifier's execution log). The libraries the test depends on (`hello_lib`, `_stage`) are neither analyzed nor format-checked.

On `eba44d8` this hides a real violation: `spike/hello/lib/src/pages.dart` is not formatted for Dart 3.13.5. `fvm dart format` wants a blank line between `import 'counter_state.dart';` and `import 'package:greeting/greeting.dart';`. The widget test passes, but `tool/bazelw build --config=lint --keep_going //spike/...` fails DartFormat on `//spike/hello:_stage` and `//spike/hello:hello_lib`.

**Status at `d29ee32`:** `pages.dart` is formatted, and the AC8 check `tool/checks/T-0014-AC8_configs_parse.sh` now runs a real `build --config=lint //spike/...`, which analyzes and format-checks all 4 first-party targets (Verifier re-run). The gotcha itself, that `test` gates only top-level targets, is still true: the AC4 execution log still shows 1 DartAnalyze and 1 DartFormat, both on `widget_test`.

## Implications
- A green `bazel test` is not a lint gate. CI and `tool/verify.sh` must also run `build --config=lint //...` (or pass the library targets as top-level targets).
- Plan 05's per-tier test invocations should not count on `test` to enforce format and analysis.
