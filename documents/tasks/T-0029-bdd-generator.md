# T-0029: BDD generator under Bazel (`.feature` → tests) + `mc_bdd_tests` macro + `mc_test_steps` skeleton (P3-05, patch 0003)

| Field | Value |
|---|---|
| Status | In Verification |
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

## Verification plan (Engineer)
| AC | Layer | Test / check | Evidence (`documents/evidence/T-0029/engineer/`) |
|---|---|---|---|
| AC1 | L2 | `tool/checks/T-0029-AC1_junit_names.sh` (runs `//spike/bdd_sample:bdd_test` uncached and reads its `test.xml`); scenarios tagged `@T-0001-AC1`, `@T-0029-AC1`, `@T-0029-AC4` | `T-0029-AC1_junit_names.md`, `T-0029-AC1_bdd_test.xml`, `generated/` |
| AC2 | L1 | `tool/checks/T-0029-AC2_missing_step.sh` (manual fixtures `//spike/bdd_sample/test/negative:missing_step` and `:shadowed_step`; hashes every file under `spike/bdd_sample` + `git status --ignored` before and after); fork test `bdd_generator_test` ("missing steps fail naming each of them") | `T-0029-AC2_missing_step.md` |
| AC3 | L1 | `tool/checks/T-0029-AC3_scaffold.sh` (`bazel run //tool/bdd:scaffold` on a temp copy) | `T-0029-AC3_scaffold.md` |
| AC4 | L1 | `tool/checks/T-0029-AC4_no_analyzer.sh`; `//utility/mc_test_steps:data_table_test` (`T-0029-AC4 DataTable keeps the generated const shape`); the `greeting_table.feature` scenario `[T-0029-AC4]` | `T-0029-AC4_no_analyzer.md`, `T-0029-AC4_cquery_notool_deps.txt`, `T-0029-AC4_tool_closure_generator_targets.txt` |
| AC5 | L2 | `tool/checks/T-0029-AC5_stock_fallback.sh` (stock bdd_widget_test 3.0.5 + build_runner in an overlay copy, then `flutter test`) | `T-0029-AC5_stock_fallback.md`, `T-0029-AC5_fallback_junit.xml`, `T-0029-AC5_stock_greeting_browse_test.dart` |
| AC6 | L0/L1 | `tool/rules_fork.sh check`, `tool/bazelw test //...`, `tool/bazelw build --config=lint //...`, `tool/bazelw run //tool/mc_arch_check:bin`, `test @rules_dart//dart/ext/bdd:all`; upstream draft `documents/upstream/U-D-bdd/` | `T-0029-AC6_gates.md` |

## Log
- 2026-11-24: Created and dispatched (codegen wave, Phase A3).
- 2026-11-24 (Engineer): Done in one pass, inside the R28 timebox; no fallback needed. Patch `0003-ext-bdd-generator.patch` (`dart/ext/bdd/`, ext lock + `bdd_widget_test: 3.0.5`). Deviations from plan 03 §4.4 (F-0027): the generator is a plain `dart_binary` speaking the shim contract (not `shimMain`); step indexes go to `dart_sqlcodegen` as `parts` (`asset_deps` refuses other packages' files); the analyzer is in the generator's exec closure (via `dart_style`), so AC4 is checked on `--notool_deps`. `tool/verify.sh` does not exist yet; its gates were run one by one (AC6).
- 2026-11-24 (Engineer, R28 fix round after Verifier FAIL `909321e`): (1) imports re-sorted after the rewrites, stubs formatted at the package's language version, the AC3 check now builds scaffolded stubs under `--config=lint`; (2) `dart/ext/bdd` format-clean, and the fork's own `bazel test //dart/ext/bdd:all` passes (it also needed the fork's `MODULE.bazel.lock` and 8 `// ignore: implementation_imports`, matching `builder_shim.dart`); (3) AC5 evidence is now written (the `--out` path was relative to the scratch dir); (4) F-0027 fact 11 and U-D-bdd: 0003 is rebased onto 0001+0002 at merge time; (5) BUILD comment corrected; (6) the scaffold reads `:step_index`, which now lists only `lib/src/<group>/**`; (7–9) `mc_bdd_tests` handles a root-level feature, fails on target-name collisions and on empty `features`; (10) duplicate local step basenames fail; (11) bad `--config` / index JSON and wrongly typed options give a `BddGenerationError`; (12) `../` step folders are accepted; (13) the scaffold scans the same top-level features and validates the same config keys; (14) the AC5 overlay keeps each dep's `flutter:` section (and copies `assets/`); (15) every AC4 `rc=1` branch reports a FAIL line. Fork tests: 15.
- 2026-11-25 (Engineer, merge prep after Verifier PASS `73ab4bd`): merged `origin/main` (0aab035, patches 0001 retrofit + 0002 injectable). Patch 0003 rebuilt in a fresh fork on top of 0001+0002 (fork `9fd728e6`): the fork `MODULE.bazel.lock` hunk is dropped (queue rule); `bdd_widget_test: 3.0.5` sits in sorted order in `dart/ext/pubspec.yaml`; `dart/ext/pubspec.lock` re-resolved with every generator: added bdd_widget_test 3.0.5, characters 1.4.1, cucumber_gherkin 42.0.1, cucumber_messages 34.2.1, diacritic 0.1.6; no version moved; `build` 4.0.11. 0001/0002 restored byte-identical from origin/main. Root `pubspec.yaml` = union of members (`pub get`: root lock unchanged); overlay lock re-resolved (adds the 4 BDD packages only); `MODULE.bazel.lock` regenerated by Bazel. AC5 check fixed for the merged overlay pubspec (it already declares `dio`); its scratch resolve now reports a harmless `test_api 0.7.15 -> 0.7.12` (the SDK's `flutter_test` pin in the scratch package only). F-0027 facts renumbered.

## Outcome
Done (Engineer; awaiting Verifier).
- **Fork patch** `third_party/rules_patches/ai_rules_dart/0003-ext-bdd-generator.patch`: `bdd_feature_test` / `bdd_step_index` / `bdd_suite_main`, generator, scaffold library, 15 fork tests. Rebased onto 0001+0002; `check` replays all 3 strictly (F-0027 fact 11).
- **`tool/bazel/defs.bzl`** `mc_bdd_tests` (one `:bdd_test` per package; `setup` hook for fixture sets); `tool/bazel/BUILD.bazel` is new.
- **`utility/mc_test_steps`** skeleton: `DataTable`, `the backend serves`, `I tap`, `I see`, `I don't see`, `I see the texts` (table), `:step_index`.
- **`tool/bdd:scaffold`** (`tool/bazelw run //tool/bdd:scaffold -- //<pkg>`).
- **`spike/bdd_sample`**: two tagged features over `mc_test_utils` / `initFlow` (3 scenarios), negative fixtures in `test/negative/` (manual).
- **Overlay**: `bdd_widget_test: 3.0.5` in `tool/build_runner_overlay` (AC5 only).
- Findings: [F-0027](../findings/F-0027-bdd-generator-under-bazel.md). Upstream: [U-D-bdd](../upstream/U-D-bdd/README.md).
- Follow-ups (for `pending-work.md`): `docs/ext.md` section + e2e exemplar before filing upstream; P5-02 fills `mc_test_steps`; buildgen emits `mc_bdd_tests`; if R28 is ever used, the stock path needs `externalSteps` by `src/` path and a `DataTable` bridge (F-0027 fact 10); `tool/verify.sh` should run the T-0029 checks.
