# T-0055: `tool/e2e_ios.sh` must fail a target whose app did not build (false PASS)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-27 `5e33a15`; Verifier PASS `829d672`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (verification tooling; negative controls required; ADR-0011) |
| Branch | `fleet/T-0055-e2e-false-pass` |
| Created | 2026-11-27 |
| Depends on | — |
| Related | T-0054 handoff (found it); ADR-0006 (e2e evidence); `tool/e2e_ios.sh`; protocol "Flaky tests" |

## Goal
The T-0054 engineer saw `tool/e2e_ios.sh` report PASS for two targets that did not compile. The Xcode build failed, and the app the previous target had installed ran its own test instead. Every e2e PASS in our evidence depends on this script, so it must never report a target as passing unless that target's own build ran.

## Scope
- **In:**
  - Reproduce the false PASS: a target with a compile error, run after a target that passes.
  - Root-cause why the runner's exit code is 0. Is it `flutter drive` behaviour, or how the script reads `rc`? Record the answer in a finding.
  - Fix it in depth. Both defences are needed:
    1. Before each target, uninstall the app from the simulator (`simctl uninstall <udid> <bundle id>`), so a stale build can never run.
    2. A target fails if its log contains a build-failure marker, whatever the exit code. At minimum: `BUILD FAILED`, `Error (Xcode)`, `Could not build the application`, `Error: Compilation failed`, and a Dart compile error line. Keep the list in one place and document it.
  - Add a positive identity check if it's cheap. For example, the target logs a marker naming its own file, and the script requires that marker.
  - Re-baseline: run the **full mini_client e2e suite on `origin/main`** with the fixed script on your own simulator. Report any target that now fails: it was a hidden false PASS.
- **Out:** Android, CI.

## Acceptance criteria
- **T-0055-AC1:** Repro and negative controls, all through the real script on your own simulator.
  - (a) A compile-error target after a passing target is FAIL, with the reason "build failed" in the summary.
  - (b) A compile-error target as the only target is FAIL.
  - (c) A target whose test fails at runtime is still FAIL.
  - (d) A good target is still PASS.
  - (e) With fix 1 alone and with fix 2 alone, (a) is still FAIL. Each defence works on its own.
- **T-0055-AC2:** Script tests. If the repo has shell tests for `e2e_ios.sh`, extend them. Otherwise add a fake `--runner-cmd` test that prints each marker with exit 0, and check that every marker yields FAIL. Name them `T-0055-AC2`.
- **T-0055-AC3:** Re-baseline. The full mini_client e2e on `origin/main` (latest at the time you run it) passes with the fixed script, or every failure is reported to the TL with its log. The summary goes in evidence.
- **T-0055-AC4:** Gates: `shellcheck` on the script if available, `test //...`, and the finding `F-0055-e2e-false-pass.md`. Update `tool/README.md` (e2e section).

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27 (Engineer): Repro first. A scratch copy of mini_client (`prepare_pub_project.sh`) with `zz_good_test` then `zz_broken_test` (compile error), through the unmodified script: `RESULT: PASS (2 targets)`, broken target log ends `# exit code: 0` (`evidence/T-0055/engineer/before-fix/`).
- Root cause: `flutter drive` itself exits 0. After "Application failed to start on attempt: 1" it installs and runs the leftover `build/ios/iphonesimulator/Runner.app` of the previous target. Written up in F-0055.
- Found that `simctl uninstall` alone (the task's defence 1) does NOT fix it: a broken target alone on a brand-new simulator still ran the other target's test, exit 0 (`intermediate-uninstall-only-*`). Defence 1 therefore also deletes `build/ios/iphonesimulator`; the marker scan (defence 2) caught the run.
- Implemented both defences in `tool/e2e_ios.sh` (markers in `E2E_BUILD_FAIL_MARKERS`, new `--bundle-id`), tests `T-0055-AC2` in `tool/test/e2e_ios_test.sh`, README e2e section, F-0055.
- Merged origin/main (5fdcf80) and ran the full mini_client e2e with the fixed script: 11 of 11 PASS.

## Outcome
The runner can no longer report PASS for a target whose app did not build. Two independent defences were proven alone and together; the full suite still passes.

| AC | Evidence (all under `documents/evidence/T-0055/engineer/`) |
|---|---|
| AC1a, c, d | `ac1abcd-both-defences/`: good PASS, broken `FAIL (build failed: BUILD FAILED)`, runtime-failing target FAIL (exit 1), good again PASS. Overall exit 1. `e2e-summary.md`, `run.out`. |
| AC1b | `ac1b-broken-alone/`: broken as the only target is `FAIL (build failed: BUILD FAILED)`. |
| AC1e | `ac1e-defence1-only/` (marker scan off): broken FAIL, exit 1, good PASS. `ac1e-defence2-only/` (no uninstall, no delete): broken `FAIL (build failed: BUILD FAILED)`. Run with temporary copies of the script (deleted). `intermediate-uninstall-only-*` show uninstall alone is not enough. |
| Before the fix | `before-fix/`: the false PASS. |
| AC2 | `tool/test/e2e_ios_test.sh`: `test_T-0055-AC2_every_marker_is_found_in_a_log` and `test_T-0055-AC2_fake_runner_printing_a_marker_with_exit_0_is_fail`. Full suite 15 of 15 PASS: `e2e_ios_test-full-suite.txt`. Negative control (marker scan disabled, both tests FAIL): `ac2-negative-control.txt`. |
| AC3 | `rebaseline/`: all 11 mini_client targets PASS on origin/main 5fdcf80 plus this branch; `e2e-summary.md`, `run.out`. No hidden failure. |
| AC4 | `test-all-bazel.txt`: `test //...` 176 of 176 pass. `shellcheck` is not installed here (`bash -n` is clean). F-0055 and `tool/README.md` updated. |

Notes for the TL:
- Positive identity check was not added (see F-0055, "Not done").
- The bundle id the build installs under is `com.emiliev.miniClient` (from `flutter create`), not Q-004's `com.emiliev.miniclient`. The script reads the Xcode project, so it does not matter, but the Bazel and pub builds differ in case.
- Earlier T-0036 / T-0053 / T-0054 e2e PASSes that ran several targets in a row could in principle have been false; the re-baseline shows the current targets all build and pass, so none of them was hiding a failure now.

## Review round
`/code-review` found 2 important issues and 6 nits. All are fixed on this branch.

| # | Finding | Fix | Proof |
|---|---|---|---|
| 1 | `Application failed to start on attempt` is also printed when a launch retry recovered (false FAIL) | Dropped as a marker. The before-fix log shows a real build failure always also prints `BUILD FAILED`, `Failed to build iOS app` and `Could not build the application`; there is no "Built ..." success line to condition on (a good log only has `Xcode build done.`, which a failed build prints too). F-0055 explains. | `test_T-0055-AC2_every_marker_is_found_in_a_log` (retry alone not reported), `test_T-0055-AC2_fake_runner_printing_a_marker_with_exit_0_is_fail` (attempt-1 + good run, exit 0 = PASS; attempt-1 + `Could not build the application` = FAIL). Mutation (marker restored) fails the unit test: `review-negative-controls.txt`. |
| 2 | Build-dir delete breaks custom runners | Deleted only for a runner command with `flutter drive` and without `--use-application-binary` / `--no-build`; new `--keep-build` opt-out; documented in `tool/README.md` and `--help`. | `test_T-0055-AC1_stale_build_dir_removed_only_for_flutter_drive_runner` (unit), `test_T-0055-AC1_keep_build_flag_through_the_script` (real script, fake runner). Mutation fails. |
| 3 | Bundle id | `xcodebuild -showBuildSettings -scheme Runner -configuration Debug`, pbxproj parse as fallback, `$(VAR)` refused. Resolved once per run. Real project gives `com.emiliev.miniClient`. | `test_T-0055-AC1_bundle_id_resolution`; the smoke log shows `uninstalled com.emiliev.miniClient`. |
| 4 | Log claimed a failed uninstall | `uninstalled <id>` only when `simctl` returns 0, else `uninstall of <id> failed or app not installed`. | same unit test; mutation fails. |
| 5 | Header line count fragile | The script writes `# --- runner output ---`; only what follows is scanned. | `test_T-0055-AC2_command_text_with_marker_is_not_a_failure` (command text has `BUILD FAILED`: PASS), unit control; mutation fails. |
| 6 | `bazel-test.txt` missing | It was never committed: `.gitignore` has `bazel-*`. Renamed to `evidence/T-0055/engineer/test-all-bazel.txt` and committed (176 of 176; re-run at the end of this round, see below). | |
| 7 | AC IDs in test names | New `T-0055-AC1` tests: `..._good_pass_runtime_fail_build_fail` (good PASS, runtime failure plain FAIL, build failure FAIL, broken alone FAIL), `..._stale_build_dir_...`, `..._keep_build_flag_...`, `..._bundle_id_resolution`. AC1e, AC3 and AC4 are run logs, not tests: AC1e = `ac1e-*` dirs, AC3 = `rebaseline/`, AC4 = `test-all-bazel.txt`. | |
| 8 | Leaking test helpers | Helpers are defined once at top level with a `t55_` prefix; test-local functions are unset. | |

Re-runs: the full `tool/test/e2e_ios_test.sh` (`e2e_ios_test-full-suite.txt`), and a real smoke on an own simulator, a good target then the broken throwaway (`review-smoke/`): good PASS, broken `FAIL (build failed: BUILD FAILED)`, simulator deleted.

Answers for the TL:
- The `mc-T-0012-*` simulators were created by my own runs of `tool/test/e2e_ios_test.sh` (it uses `T-0012` as its task id). I never deleted one by hand; the suite deletes its own simulators on exit. The only simulator I saw that was not mine, `mc-T-0052-verifier-*`, was left alone.
- Bundle id mismatch (`miniClient` built, `miniclient` in Q-004): recorded in F-0055 for the TL to file.

## Merge (TL)
- 2026-11-27: Found by the T-0054 engineer. Review-first: `/code-review` found 2 important issues (a launch-retry marker would false-FAIL; the unconditional build-dir delete broke custom runners) and 6 nits, all fixed at `5d8f6f5`. A single Sonnet Verifier pass gave PASS `829d672` (about 82k tokens, interrupted once by the usage limit). It reproduced the false PASS on the old script and proved each defence alone; 5 kinds of real breakage were all caught. Re-baseline: the full suite on `main` passed 11/11, so no earlier evidence hid a failure. The TL merged `--no-ff`; on the merge result `tool/test/e2e_ios_test.sh` passed 20/20 and `test //...` 178/178.
