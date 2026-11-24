# Verification report — T-0029: BDD generator under Bazel (`mc_bdd_tests`, `mc_test_steps` skeleton)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0029-bdd-generator` @ `a4e984b`. This was a detached checkout, because the branch is checked out in the Engineer's worktree.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0029-verifier`, with no `.bazelrc.user` override. It builds the committed queue: pin `e7163aa` + `0003-ext-bdd-generator.patch`.
- **Fork dir:** `MC_FORK_DIR=/tmp/mc-fork-T-0029-verifier`, the Verifier's own.
- **Simulator:** none. There is no UI or e2e in scope.
- **Verdict:** **FAIL**. AC1 to AC5 pass. AC6 fails on one gate: `dart format` is not clean on the patch's Dart files (D2). There is also one major scaffold defect (D1). Both are mechanical fixes, within R28's one fix round.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Patch queue | `tool/rules_fork.sh check` | PASS: `check ai_rules_dart: 1 patch(es) apply strictly on pin e7163aab8f91`; `ai_rules_flutter: queue empty, OK` |
| Patch = export | `rules_fork.sh checkout ai_rules_dart`, then `export ai_rules_dart`, then diff against the committed patch | PASS: byte-identical, sha1 `3a534b2b…` for both. Only the file name differs: export names it `0001-ext-hermetic-…`, and the queue renamed it to `0003-…` on purpose. The tree and `.bazelrc.user` were restored afterwards. |
| Tests | `test //... --keep_going --nocache_test_results --lockfile_mode=error` | PASS: `Executed 49 out of 49 tests: 49 tests pass.` (includes `//spike/bdd_sample:bdd_test` and `//utility/mc_test_steps:data_table_test`) |
| Fork tests | `test --nocache_test_results @rules_dart//dart/ext/bdd:all @rules_dart//dart/ext/_shared/combining_shim:all` | PASS: 2/2 |
| Lint | `build --config=lint //... --keep_going` | PASS: exit 0 |
| Arch | `run //tool/mc_arch_check:bin` | PASS: `mc_arch_check: OK`, exit 0 |
| Format (repo) | `fvm dart format --output=none --set-exit-if-changed` on the 13 touched repo `.dart` files, after `fvm flutter pub get --enforce-lockfile` | PASS: `Formatted 13 files (0 changed)`. `pub get` with an enforced lockfile also succeeded, so the root `pubspec.lock` needs no change for the 2 new workspace members. |
| **Format (patch)** | `fvm dart format --output=none --set-exit-if-changed dart/ext/bdd` in the fork checkout | **FAIL**: `Formatted 4 files (4 changed)`. That covers `bin/generator.dart`, `lib/bdd_generator.dart`, `lib/scaffold.dart` and `test/bdd_generator_test.dart` (10, 48, 2 and 19 changed lines). The existing ext code is clean: `dart format dart/ext/_shared dart/ext/freezed` gives `0 changed`. |
| Upstream draft | `documents/upstream/U-D-bdd/README.md` | Exists. Its claim "`bazel test //dart/ext/bdd:all` passes" was only shown from the consumer side (see D2). |

`tool/verify.sh` does not exist yet, so its gates were run one by one, as the Engineer did.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0029-AC1 | `@T-0001-AC1` reaches the JUnit name | `//spike/bdd_sample:bdd_test`; `tool/checks/T-0029-AC1_junit_names.sh` | Yes. I ran the test uncached and read `test.xml` myself: `greeting_browse Greeting The greeting is shown [T-0001-AC1]`, `… Tapping the button says goodbye [T-0029-AC1]`, `greeting_table Greeting texts Every label is on screen [T-0029-AC4]`. The tag comes from the scenario through `tags:` into `mcTestWidgets`. **Mutations** (each exit 3, `:bdd_test FAILED`, then reverted): (1) shared `iSee` changed to `findsNothing` → `errors="2"`, `MUTANT "Hello, Bazel"`; (2) the data-table step `iSeeTheTexts` reads a wrong cell → `errors="1"` on `[T-0029-AC4]`; (3) the feature expectation changed to `'Hello, World'` → regenerated and red. After reverting: PASSED. | PASS |
| T-0029-AC2 | A missing step fails the build, naming it; no writes outside `bazel-out` | `:missing_step` and `:shadowed_step` fixtures; `T-0029-AC2_missing_step.sh`; fork test "missing steps fail naming each of them" | Yes. `build --disk_cache= //spike/bdd_sample/test/negative:missing_step` gives `BDD generation failed: missing_step.feature: 2 step(s) have no definition:` with `"I count {3} craters" -> step/i_count_craters.dart (iCountCraters)` and `"the moon is made of cheese" -> …`. The shared `I tap` is correctly not listed. `:shadowed_step` gives `step/i_see.dart shadows package:mc_test_steps/mc_test_steps.dart`. **Through the real macro**: I added a scenario with 2 undefined steps to `greeting_browse.feature` and built `:bdd_test` with `--strategy=DartSqlCodegen=worker --noworker_sandboxing` (the risky unsandboxed-worker case; the action has `supports-workers: 1`). It named both missing steps. **Whole-tree hash** (every regular file in the worktree except `.git`, 1,414 entries, plus `git status --porcelain --ignored`): `5d4c96bd…` / `ebca1170…` before and after. No stubs appeared. | PASS |
| T-0029-AC3 | `scaffold` writes a stub into `test/feature/step/` | `T-0029-AC3_scaffold.sh`; my own run on the real tree | Yes. I added `greeting_scaffold.feature` (two new steps, one with a data table and 2 params) and ran `run //tool/bdd:scaffold -- //spike/bdd_sample`. It wrote `spike/bdd_sample/test/feature/step/i_wave_times_at.dart` (`num param1, String param2`) and `the_greeting_rows_are.dart` (`bdd.DataTable dataTable`), and no stubs for shared steps. The second run said `every step is defined`. A bad package gave `no pubspec.yaml with a name in spike/nope`. **Do the stubs compile?** The Dart compiles: with the imports sorted by hand, `:bdd_test` ran 4 cases and only `[T-0029-AC3]` failed, with `UnimplementedError`. **But** the data-table stub as written fails `:bdd_test`'s `dart_analyze` aspect: `the_greeting_rows_are.dart:2:1 … directives_ordering` (D1). The Engineer's check never builds the stubs. The AC as written (a stub appears) is met. All scaffold files were removed afterwards. | PASS (with D1) |
| T-0029-AC4 | No analyzer in `:bdd_test`; a data-table feature compiles against `DataTable` | `T-0029-AC4_no_analyzer.sh`; `data_table_test` (`T-0029-AC4 DataTable keeps the generated const shape`); `greeting_table.feature` `[T-0029-AC4]` | Yes, with the TL's reading (no analyzer in the test's own target-config closure). `cquery 'deps(//spike/bdd_sample:bdd_test)' --notool_deps` gives 2,952 targets with no analyzer, `_fe_analyzer_shared`, `build`, `dart_style` or `bdd_widget_test`. The only grep hit is the source file `material_color_utilities/lib/dislike/dislike_analyzer.dart`, a false positive. With tool deps (4,458 targets), every analyzer-family target is in config `b1a3e4e` only (`platform_suffix: exec`). That is the generator's config; the test is in `906ae0c`. Direct dependents (`rdeps …, 1`): `analyzer` ← `dart_style`, `build`; `dart_style` ← `bdd_generator`, `bdd_widget_test`; `build` ← `bdd_widget_test`; `bdd_widget_test` ← `bdd_generator`. So the exec-config generator is the only root. The generated `greeting_table_test.dart` imports `package:mc_test_steps/mc_test_steps.dart as bdd` and calls `const bdd.DataTable([...])`, and it runs (mutation 2 above proves the table rows reach the step). | PASS |
| T-0029-AC5 | Stock bdd_widget_test 3.0.5 fallback stays traceable | `T-0029-AC5_stock_fallback.sh` | Yes. I ran it myself (exit 0). Overlay resolve: `bdd_widget_test 3.0.5` (sha `0d78497f…`), with no drift from the committed overlay lock. build_runner: `bdd_widget_test:featureBuilder on 1 input: 1 output`. The stock output has `tags: ['T-0001-AC1', 'smoke']` and `tags: ['T-0029-AC1']`, and the stock Builder wrote no step stubs. `flutter test` names: `success greeting_browse Greeting The greeting is shown [T-0001-AC1]` and `success … Tapping the button says goodbye [T-0029-AC1]`. | PASS |
| T-0029-AC6 | Fork check, `test //...`, lint, `mc_arch_check`, upstream draft | See the gates table | All green except `dart format` on the patch's 4 Dart files (D2). | **FAIL** |

## Determinism and caching
- **Byte-identical rebuild:** I ran `clean`, then `build --disk_cache=` on the two `_bdd_test_gen_*` targets and `:bdd_test_main` (`62 processes: … 35 worker`), twice. The sha1 values were identical both times: `bdd_test_main.dart c80e5d8a…`, `greeting_browse_test.dart 8ff84fe5…`, `greeting_table_test.dart d8c229d9…`. These are also identical to the Engineer's `engineer/generated/*.dart`.
- **No-op rebuild:** `Build completed successfully, 1 total action`, and the execution log has 0 spawns, so the generator did not run.
- **Cutoff:** an edit to `lib/bdd_sample.dart` re-ran only `DartAnalyzerSummary`, `DartImportCheck`, `DartKernel` and `DartKernelLink`, with **no `DartSqlCodegen`**. An edit to a local step file re-runs both `DartSqlCodegen` actions. This is expected: steps are `asset_deps` inputs, although the generator only needs their file names. It's a possible optimisation (observation O3).

## Test-integrity audit
- **Each AC has a `T-0029-ACn`-named test or evidence:** yes.
  - Check scripts: `tool/checks/T-0029-AC{1..5}_*.sh`.
  - Tagged scenarios: `[T-0029-AC1]`, `[T-0029-AC4]`.
  - Named test: `T-0029-AC4 DataTable keeps the generated const shape`.
  - AC6 is the gates evidence.
- **Tests deleted, skipped or weakened:** none. The only modified files are `MODULE.bazel`, `MODULE.bazel.lock`, `pubspec.yaml`, the overlay `pubspec.{yaml,lock}` and the task file; everything else is added. `tags = ["manual"]` on the two negative fixtures is deliberate: they must fail to build, and the AC2 script builds them. They are not part of `//...` and not in any automated gate until `tool/verify.sh` runs the T-0029 checks (already a follow-up).
- **Lint suppressions:** none in hand-written source. `// ignore_for_file: type=lint` is emitted into the generated suite main (`defs.bzl` in the patch, line 342 of the patch file). The stock emitter also writes `type=lint, type=warning`. Both are in bazel-bin only, and F-0027 fact 7 says the aspects skip generated files anyway.
- **Golden updates:** none.
- **Patch = export:** yes (see the gates table).
- **Lockfiles:** I compared `MODULE.bazel.lock` semantically (JSON) between `origin/main` and the branch. It is purely additive: 5 `facts` entries and 5 `generatedRepoSpecs` (`bdd_widget_test` 3.0.5, `characters` 1.4.1, `cucumber_gherkin` 42.0.1, `cucumber_messages` 34.2.1, `diacritic` 0.1.6). The other changes are the regenerated `lock_packages` / `packages` lists and the ext-lock file hash in `recordedInputs`. Nothing is removed and no versions change. The 95 "deleted" text lines are re-serialisation. The overlay lock only adds the same 4 hosted packages. `--lockfile_mode=error` passes.
- **Unrelated changes:** none. The engineer touched no TL-owned files (STATUS, BOARD, journal, indexes).

## Mutation checks
| Mutation | Expected | Observed |
|---|---|---|
| `iSee` → `findsNothing` | `:bdd_test` red | FAILED, `errors="2"` (the 2 scenarios that use it) |
| `iSeeTheTexts` reads `'${row['text']}MUTANT'` | red on the table scenario | FAILED, `errors="1"` `[T-0029-AC4]` |
| Feature `Then I see {'Hello, World'}` | regenerated, red | FAILED, `Found 0 widgets with text "Hello, World"` |
| 2 undefined steps added to a macro feature | build error naming both | named `the_gizmo_is_frobbed.dart`, `the_sky_turns.dart` |

## Issues found
1. **D1 (major): the scaffold's data-table stub fails the package's analyze gate.**
   - The data-table stub comes out as `import 'package:mc_test_steps/mc_test_steps.dart' as bdd;` followed by `import 'package:flutter_test/flutter_test.dart';`. The `dart_analyze` aspect on `:bdd_test` (always on under `test`) then fails with `directives_ordering`.
   - **Cause:** `_rewriteImports` swaps the `package:bdd_widget_test/data_table.dart` line for `dataTableImport` in place. The stock line sorted before `flutter_test`, and the new one does not. This is in `missingStepStubs` → `_rewriteImports(generateStepDart(…))`: patch lines 631–651 and 743–755 (`dart/ext/bdd/lib/bdd_generator.dart`).
   - **Gap in the check:** `tool/checks/T-0029-AC3_scaffold.sh` scaffolds into a temp workspace and never builds the stubs, so it can't catch this.
   - **Repro:** add a feature with a table step under `spike/bdd_sample/test/feature/`, run `tool/bazelw run //tool/bdd:scaffold -- //spike/bdd_sample`, then `tool/bazelw test //spike/bdd_sample:bdd_test`.
   - **Fix:** sort the imports in the stub, or emit the table import after `flutter_test`. Add a build of a scaffolded stub to the AC3 check.
2. **D2 (major; fails AC6's format gate): the patch's Dart files are not `dart format`-clean.**
   - Running `dart format --set-exit-if-changed dart/ext/bdd` in a fork checkout changes 4 files. For example, `lib/scaffold.dart:17` is a `for` header over 80 columns.
   - Our gates don't see this, because the consumer's lint aspect skips external repos. But the fork's own `.bazelrc` runs `test --output_groups=+dart_format` (lines 36–38), so U-D-bdd's claim "`bazel test //dart/ext/bdd:all` passes" holds only from the consumer side.
   - **Fix:** run `fvm dart format dart/ext/bdd` in the fork, re-export, and run `rules_fork.sh check`.
   - Plain `dart analyze bdd` with the fork's `analysis_options.yaml` also reports about 80 infos, mostly `specify_nonobvious_local_variable_types`. Some are resolution artifacts of a CLI run. Existing ext code isn't clean under plain `dart analyze` either (15 infos), so I don't count this as a defect. Re-check under the fork's own Bazel aspect before filing upstream.
3. **D3 (minor): the Engineer's AC5 evidence is missing.** The task's verification plan (`documents/tasks/T-0029-bdd-generator.md:44`) and F-0027's Evidence section list `T-0029-AC5_stock_fallback.md`, `T-0029-AC5_fallback_junit.xml` and `T-0029-AC5_stock_greeting_browse_test.dart` under `engineer/`, but none were ever committed. The Verifier's copies are in `verifier/`.
4. **D4 (minor): the stacking statement in F-0027 fact 11 is stale.**
   - `documents/findings/F-0027-bdd-generator-under-bazel.md:22` and `U-D-bdd/README.md:47` say 0003 conflicts only with T-0028, in `pubspec.lock` (`dio`).
   - Against the current branch heads, `git am` on the pin gives:
     - `0003` alone applies;
     - `0002` (T-0028 @ `ced0c05`) then `0003` both apply;
     - `0001` (T-0027 @ `eee1877`) then `0003` **fails in `dart/ext/pubspec.lock:217` and in `dart/ext/pubspec.yaml:25`**. 0001 inserts `retrofit_generator` inside 0003's context lines, and `dio` comes from 0001, not 0002.
   - So the yaml does not "merge cleanly" either.
5. **D5 (minor): a comment contradicts F-0027 fact 6.** The patch's `dart/ext/bdd/BUILD.bazel` header (patch line 19) says "No analyzer and no package:build in the generator's closure", but analyzer and build are in it (exec config, through `dart_style` and `bdd_widget_test`).
6. **D6 (minor): the scaffold's view of shared steps differs from the generator's.**
   - `tool/bdd/scaffold.dart:13` scans all of `utility/mc_test_steps/lib/src`, including `data_table.dart`, while `:step_index` excludes it. A step text that maps to `data_table.dart` would get no stub, yet the build would call it missing.
   - Stubs are also formatted at `DartFormatter.latestLanguageVersion` (patch line 741), not at the package's language version.

## Interaction with patches 0001 / 0002 (for queue planning; not verified)
- **Strict order 0001 → 0002 → 0003 does not apply today.** 0002 fails on 0001 in `docs/ext.md:46`. 0003 fails on 0001 in both `dart/ext/pubspec.{lock,yaml}` (D4). Whichever patch merges second and third must be re-exported on top of the earlier ones in a fork. Bazel's lenient patcher can accept or drop stale hunks (F-0022), so `rules_fork.sh check` is the only reliable signal: run it on every merge.
- **`dart/ext/pubspec.lock` must be re-resolved, not hand-merged.** None of the three changes an existing version (all pure inserts: 0001 adds `dio`, `dio_web_adapter`, `retrofit`, `retrofit_generator`; 0002 adds `injectable`; 0003 adds 4 packages), so a joint resolve is likely to succeed. But bdd_widget_test is pinned to 3.0.5 because 3.1.x needs `build ^5`. If retrofit_generator or injectable ever forces `build` 5, 0003 breaks.
- **`MODULE.bazel.lock` will conflict textually** on every combination: the ext-lock hash in `recordedInputs` and every `lock_packages` list. Regenerate it after the queue is final; don't hand-merge it. The `patches = [...]` lines in `MODULE.bazel` also all insert at the same place.
- **The overlay lock is touched by both T-0027 and T-0029.** `tool/build_runner_overlay/pubspec.lock` changes in both tasks (and T-0028 adds its own `injectable/` overlay). After merging, re-resolve it and re-run the AC5 check: it reports drift from the committed overlay lock.

## Observations (no action required)
- O1: the generator's flag parser assumes every `--flag` takes a value, and drops a `--dep` without `|` silently. That's fine for the `dart_sqlcodegen` contract as it stands.
- O2: generated tests import `package:mc_test_steps/mc_test_steps.dart` twice (once `as bdd`, once unprefixed). It's harmless.
- O3: step-file edits re-run generation for every feature in the package, because contents are inputs but only names matter. That's a possible optimisation (step names in a JSON input).

## Evidence
`documents/evidence/T-0029/verifier/`:
- `T-0029-AC1_bdd_test.xml`: the Verifier's uncached `:bdd_test` run;
- `T-0029-AC4_analyzer_family_configs.txt`: analyzer-family targets with their configuration, all `b1a3e4e` (exec);
- `T-0029-AC5_fallback_junit.xml` and `T-0029-AC5_stock_greeting_browse_test.dart`: the Verifier's AC5 run.

## Notes for the Tech Lead
- The fix round needs D1 (a one-line import order fix, plus a build of a scaffolded stub in the AC3 check) and D2 (format 4 files, re-export, run `check`). D3 to D6 are documentation or small fixes that can ride along. After that, the same checks can be repeated quickly; the determinism, AC2 and AC4 results don't depend on these changes.
- The Verifier's fork dir `/tmp/mc-fork-T-0029-verifier` and output base `/tmp/mc-ob-T-0029-verifier` (shut down) can be deleted.
