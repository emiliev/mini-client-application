# mc_analysis

The shared lints. Every package's `analysis_options.yaml` is one line:
`include: package:mc_analysis/analysis_options.yaml`. The repo root includes it
too, which is what the Bazel `dart_analyze` aspect applies (`//:options` has
this package as a dep).

Tests: `tool/bazelw test //utility/mc_analysis:lints_test` runs `dart analyze`
over one fixture per rule (`test/fixtures/lints/<rule>.dart`) and asserts that
the rule reports (T-0017-AC3).

## Rules

Source `Tide` is the `tide_analysis` package from the Tide utility-layer
article (tide-core research §4.1). Source `Plan 01` is plan 01 §2 row 5 / D-06.

| Rule | Source |
|---|---|
| `always_declare_return_types` | Tide |
| `always_put_control_body_on_new_line` | Tide |
| `always_use_package_imports` | Tide |
| `annotate_overrides` | Tide |
| `directives_ordering` | Tide |
| `null_check_on_nullable_type_parameter` | Tide |
| `package_names` | Tide (reports on `pubspec.yaml`) |
| `parameter_assignments` | Tide |
| `unnecessary_brace_in_string_interps` | Tide |
| `unnecessary_const` | Tide |
| `unnecessary_constructor_name` | Tide |
| `unnecessary_getters_setters` | Tide |
| `unnecessary_library_directive` | Tide |
| `unnecessary_new` | Tide |
| `unnecessary_null_aware_assignments` | Tide |
| `unnecessary_null_checks` | Tide |
| `unnecessary_null_in_if_null_operators` | Tide |
| `unnecessary_nullable_for_final_variable_declarations` | Tide |
| `unnecessary_overrides` | Tide |
| `unnecessary_parenthesis` | Tide |
| `strict-inference` (language flag) | Plan 01 D-06 |

Also carried over from Tide: `strict-casts`, `strict-raw-types`, the error
levels (`missing_required_param`, `missing_return`, `invalid_assignment`,
`invalid_annotation_target`), and the excludes `*.g.dart`, `*.freezed.dart`,
`*.config.dart`, `**/test/feature/*_test.dart`. Plan 01 adds the gen-l10n output
exclude `**/lib/src/l10n/*_l10n*.dart`.

## Deviations from Tide's 22 rules

Two Tide rules are left out because they cannot do their job on the pinned
Dart 3.13.5 (F-0013):

- `unnecessary_await_in_return`: deprecated; the analyzer warns that it
  "shouldn't be enabled" on every project that includes this file.
- `package_prefixed_library_names`: enabled, it reports nothing on a
  mismatched `library` name, so AC3 cannot be met.

## Other deviations

- Tide's BDD exclude `**/feature**/*_test.dart` matches every test under
  `feature/` in this repo, so no hand-written feature test would be linted.
  It is narrowed to the generated output directory `**/test/feature/*_test.dart`
  (plan 05 §3, gitignored).
