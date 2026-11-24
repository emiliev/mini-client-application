# Verification report — T-0029: BDD generator under Bazel (`mc_bdd_tests`, `mc_test_steps` skeleton)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0029-bdd-generator` @ `a4e984b` (detached checkout: the branch is checked out in the Engineer's worktree)
- **Simulator:** none (no UI or e2e in scope)
- **Verdict:** _WIP — in progress_

**WIP (partial).** Done so far: patch export round-trip, `rules_fork.sh check`, AC1 (incl. 3 mutations), AC2 (incl. unsandboxed worker, whole-tree hash), AC3 (incl. stubs compiled), AC4 cquery. Still to do: AC4 path check, AC5, AC6 gates, determinism and caching, diff review, queue interaction.

## Findings so far
- Patch 0003 content is byte-identical to a fresh `rules_fork.sh checkout` + `export` (sha1 `3a534b2b…`); `check` passes.
- AC1: JUnit names carry `[T-0001-AC1]`, `[T-0029-AC1]`, `[T-0029-AC4]`. Mutating `iSee`, `iSeeTheTexts` and a feature expectation each turns `:bdd_test` red.
- AC2: missing steps are named (macro path and fixture); shadowing refused; whole-tree hash unchanged.
- AC3: stubs are written to `test/feature/step/` and compile, **but** the data-table stub has unsorted imports (`package:mc_test_steps … as bdd` before `package:flutter_test`), so `:bdd_test` fails the `dart_analyze` aspect (`directives_ordering`) until the developer sorts them by hand.
- AC4: `--notool_deps` closure (2,952 targets) has no analyzer, build, dart_style or bdd_widget_test. With tool deps, analyzer, `_fe_analyzer_shared`, build, dart_style and bdd_widget_test show up only in the exec configuration `b1a3e4e`, where the generator also is; the test is in `906ae0c`.
- Engineer evidence for AC5 (`T-0029-AC5_*`) is listed in the task file and F-0027 but was never committed.
