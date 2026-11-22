# T-0012: iOS simulator e2e runner script (stack-independent)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (worktree) |
| Verifier | crew: Verifier (fresh agent, assigned at handoff) |
| Branch | `fleet/T-0012-ios-sim-e2e-runner` |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | — (proven commands in [F-0004](../findings/F-0004-ios-verification-pipeline.md)) |
| Related | ADR-0006 (L4, L5, §6), T-0010 (wires the real app into this), T-0009 |

## Goal
One reusable command that any Engineer or Verifier runs to execute a Flutter project's e2e tests on a **freshly created, private iOS simulator**, collect screenshots into the task's evidence folder, write a summary, and **always** clean up. It must not depend on the PO's upcoming stack: the runner command is pluggable.

## Scope
- **In:**
  - `tool/e2e_ios.sh`, a bash script with this interface:
    ```
    tool/e2e_ios.sh --task T-XXXX --role engineer|verifier --project <flutter-project-dir>
                    [--target integration_test/<file>.dart]...   (default: every integration_test/*_test.dart)
                    [--driver test_driver/integration_test.dart]
                    [--device "iPhone 17 Pro"] [--runtime com.apple.CoreSimulator.SimRuntime.iOS-26-2]
                    [--evidence-dir <dir>]                        (default: <repo>/documents/evidence/<task>)
                    [--runner-cmd "<cmd using {target} {driver} {udid}>"]  (default: fvm flutter drive …)
                    [--keep-sim]
    ```
    Behaviour:
    - Pre-flight checks (`xcrun`, `fvm`, runtime and device type exist) fail fast with a clear message, before any simulator is created.
    - The simulator is named `mc-<task>-<role>-<pid>`: unique, so parallel runs are safe. It is created with `simctl create` (never `clone`), booted, then waited on with `simctl bootstatus -b`.
    - Each target runs with `SCREENSHOT_DIR` pointed at a temp dir. Its log is saved as `e2e-<target-basename>.log` in the evidence dir, and PASS/FAIL and duration are recorded per target.
    - Screenshots are copied into the evidence dir and downscaled **only if taller than 1200 px**.
    - `e2e-summary.md` is written in the evidence dir: task, role, device, runtime, simulator name, per-target result and duration, and a list of screenshots.
    - A `trap` on EXIT, INT and TERM always shuts down and deletes the simulator (unless `--keep-sim`).
    - Exits non-zero if any target fails.
  - `tool/sim_cleanup.sh`: deletes **only** simulators whose name starts with `mc-` (for orphans left by a `kill -9`). Supports `--dry-run`.
  - `tool/test/e2e_ios_test.sh`: an automated test suite, one test per AC with the AC ID in its name. It builds a throwaway fixture Flutter app on the fly in a temp dir (`fvm flutter create`, plus a 2-screen app, an `integration_test` with `takeScreenshot`, and a screenshot driver), so nothing large is committed.
  - A usage section in `tool/README.md`.
- **Out:** wiring the real mini-client app (T-0010); Android (Q-009); `tool/verify.sh` (T-0005).
- **Files / areas touched:** `tool/` only.

## Acceptance criteria
- **T-0012-AC1:** Given a fixture app whose e2e test passes and takes 2 screenshots, when `tool/e2e_ios.sh --task T-0012 --role engineer --project <fixture>` runs, then it exits 0, and the evidence dir contains both PNGs (each ≤ 1200 px tall), `e2e-summary.md` showing PASS, and the target's log.
- **T-0012-AC2:** Given a fixture whose e2e test fails, when the script runs, then it exits non-zero, `e2e-summary.md` shows FAIL for that target, and the failure log is saved.
- **T-0012-AC3:** Given any run (passing, failing, or interrupted with SIGINT mid-run), then afterwards no simulator named `mc-T-0012-*` exists.
- **T-0012-AC4:** Given two runs started at the same time (roles `engineer` and `verifier`, two separate fixture copies), then both exit 0 and each uses its own simulator.
- **T-0012-AC5:** Given an unknown `--runtime` or `--device`, when the script runs, then it exits non-zero within 10 s with an error naming the bad value, and creates no simulator.
- **T-0012-AC6:** Given orphaned `mc-*` simulators and at least one non-`mc-` simulator, when `tool/sim_cleanup.sh` runs, then every `mc-*` simulator is deleted and no other simulator is touched; `--dry-run` deletes nothing.
- **T-0012-AC7:** Given a screenshot no taller than 1200 px, then it is copied unchanged (not enlarged).

## Verification plan
| AC | Layer | Test (in `tool/test/e2e_ios_test.sh`) | Status |
|---|---|---|---|
| T-0012-AC1 | L4/L5 | `test_T-0012-AC1_pass_run_collects_evidence` | ☐ |
| T-0012-AC2 | L4 | `test_T-0012-AC2_failing_target_reports_fail` | ☐ |
| T-0012-AC3 | script | `test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint` | ☐ |
| T-0012-AC4 | script | `test_T-0012-AC4_parallel_runs_isolated` | ☐ |
| T-0012-AC5 | script | `test_T-0012-AC5_bad_runtime_or_device_fails_fast` | ☐ |
| T-0012-AC6 | script | `test_T-0012-AC6_cleanup_only_mc_simulators` | ☐ |
| T-0012-AC7 | script | `test_T-0012-AC7_small_screenshot_not_upscaled` | ☐ |

## Log
- 2026-11-22: Created after the PO asked to focus on iOS testing. Split out of T-0010 because it doesn't depend on the PO stack. Engineer dispatched in a worktree.

## Outcome
_Pending._
