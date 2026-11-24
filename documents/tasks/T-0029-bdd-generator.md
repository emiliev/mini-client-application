# T-0029: BDD generator under Bazel (`.feature` → tests) + `mc_bdd_tests` macro + `mc_test_steps` skeleton (P3-05, patch 0003)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Opus, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0029-bdd-generator` |
| Created | 2026-11-24 |
| Depends on | T-0024 (patch queue), T-0026 (`mc_test_utils`) |
| Related | [plan 03 §4 (BDD), KD7, X4, P3-05](../plan/03-bazel-integration.md), [plan 05 §3, §4, §5](../plan/05-testing-and-bdd.md), Tide's BDD ([research](../research/tide-miniclient/app-navigation-testing.md) §4.5, §4.6), README R12, **R28 (timebox and fallback)**, V2-07, ADR-0010 |

## Goal
Tide's sociable BDD feature tests (bdd_widget_test style) generated as Bazel actions. `.feature` files become `_test.dart` files, with scenario tags `@T-XXXX-ACn` carried into the JUnit test names, so ADR-0006's AC traceability is automatic. Generation reuses bdd_widget_test **3.0.5**'s parser (`FeatureFile`), not its Builder, which writes outside the declared outputs (X4).

## Timebox (R28)
One Engineer pass plus one fix round. Otherwise stop with a precise finding, and the TL switches BDD to the build_runner fallback, provided AC5 proves the fallback stays traceable.

## Scope
- **In:**
  - On the rules_dart fork: `dart/ext/bdd/`, a parser-based generator (`dart_binary`) as a `dart_codegen` per `.feature` file, plus a tag→test-name pre-pass. Exported as the next patch in the queue (`check` passes); coordinate the number with T-0027 / T-0028 (`0001` and `0002`).
  - `tool/bazel/defs.bzl`: an `mc_bdd_tests` macro building one aggregated `:bdd_test` per package (plan 05 KD6).
  - `utility/mc_test_steps` (`testonly`) **skeleton**: the `DataTable` type plus a handful of shared steps from plan 05 §3.2 (e.g. "the app is launched", "I see {text}", "I tap {text}"). The full v1 step library is P5-02, later.
  - `tool/bdd/scaffold`, which creates step stubs in `test/feature/step/`.
  - A sample feature package (or a spike) with two tagged `.feature` files over `mc_test_utils` and `initFlow`.
  - Upstream draft: `documents/upstream/U-D-bdd/`.
- **Out:** the full step library, feature work.

## Acceptance criteria
- **T-0029-AC1:** Given a feature file tagged `@T-0001-AC1`, when `:bdd_test` runs, then the JUnit case name contains `T-0001-AC1`.
- **T-0029-AC2:** Given a missing step, then the build fails naming it, and no file is written outside `bazel-out`.
- **T-0029-AC3:** Given `scaffold`, then a stub appears in `test/feature/step/`.
- **T-0029-AC4:** `cquery deps(:bdd_test)` contains no `analyzer`, and a feature with a Gherkin data table compiles against `mc_test_steps`' `DataTable`.
- **T-0029-AC5:** Given stock `bdd_widget_test` 3.0.5 in the overlay with `testMethodName: mcTestWidgets`, when it generates a tagged feature, then each scenario's tags reach `mcTestWidgets` as `tags:` and the JUnit name carries the AC ID. This decides that the R28 BDD fallback stays traceable (V2-07).
- **T-0029-AC6:** `rules_fork.sh check` passes; `test //...`, lint and `mc_arch_check` are green; the upstream draft exists.

## Log
- 2026-11-24: Created and dispatched (codegen wave, Phase A3).

## Outcome
_Pending._
