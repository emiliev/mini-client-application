# Verification report — T-0012: iOS simulator e2e runner script

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** `fleet/T-0012-ios-sim-e2e-runner` @ `805b6ab` (checked out as `fleet/T-0012-verify`)
- **Simulators:** `mc-T-0012-verifier-9507` (run a), `mc-T-0012-verifier-26295` (run c) and `mc-T-0012-verifier-dryrun` (check d), all iPhone 17 Pro on iOS 26.2. The suite also created its own `mc-T-0012-*` simulators and private `simctl --set` simulators. All were created and deleted during this verification.
- **Toolchain:** macOS `/bin/bash` 3.2.57, Flutter 3.47.8 (fvm), Xcode 26.2
- **Verdict:** **PASS**

## Gates re-run independently
T-0012 is a `tool/`-only shell task: there is no Dart code under test, so the L0 to L3 Flutter gates don't apply.

| Gate | Command | Result |
|---|---|---|
| Syntax | `/bin/bash -n` on `tool/e2e_ios.sh`, `tool/sim_cleanup.sh` and `tool/test/e2e_ios_test.sh` | OK, all 3 |
| Suite, run 1 | `tool/test/e2e_ios_test.sh` | **13 passed, 0 failed, 13 total in 417 s** (420 s wall), `RESULT: PASS` |
| Suite, run 2 (foreground, re-run on the coordinator's request) | `tool/test/e2e_ios_test.sh` | **13 passed, 0 failed, 13 total in 407 s** (410 s wall), `RESULT: PASS` |
| Pre-fix regression | the new suite against `a7aefb8`'s scripts, filtered to the 4 important-finding tests | 0 of 4 passed, as expected: every one catches its old bug (see below) |
| L4 E2E (black box) | `tool/e2e_ios.sh --task T-0012 --role verifier --project <Verifier's own fixture>` | exit 0, PASS, 3 screenshots (see Visual acceptance) |

The Engineer reported 13 of 13 in 437 s. Both of my runs agree, at 417 s and 407 s. Full output: [verifier-test-suite.txt](verifier-test-suite.txt). Black-box output: [verifier-blackbox.txt](verifier-blackbox.txt).

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0012-AC1 | Passing fixture with 2 screenshots: exit 0; both PNGs ≤ 1200 px; summary shows PASS; log saved | `test_T-0012-AC1_pass_run_collects_evidence`, `…_unwritable_screenshot_is_an_error_not_a_phantom`, `…_multiple_targets_get_unique_names`; black-box run (a) | Yes. The test asserts rc = 0, `**PASS**` in both the result and the target row, a log containing "All tests passed", and both PNGs non-empty, 1 to 1200 px tall, listed in the summary and marked "downscaled from". It would fail on any missing file, an oversize image or a wrong status. Black box (a): my own 3-screenshot counter app gave exit 0 and 3 PNGs of 552×1200 (from 1206×2622) in the new default `documents/evidence/T-0012/verifier/`. | PASS |
| T-0012-AC2 | Failing fixture: non-zero exit, FAIL in the summary, failure log saved | `test_T-0012-AC2_failing_target_reports_fail` | Yes. The test asserts rc = 1, `**FAIL**` in the result and the row, and the deliberate-failure marker in the log with no "All tests passed". | PASS |
| T-0012-AC3 | No `mc-T-0012-*` simulator left after a pass, a fail or a SIGINT | `test_T-0012-AC3_no_simulator_left_after_pass_fail_sigint`, `…_teardown_survives_second_sigint_and_kills_orphans`; black-box run (c) | Yes. Each run's simulator is checked by name after it ends. The SIGINT case confirms the runner was live when the signal was sent, then asserts rc = 130, the trap output on the console and not in the target log, the INTERRUPTED row with its log link, no surviving `-d <udid>` process, and no new `mc-T-0012-*` simulator. Black box (c): two SIGINTs to the process group gave rc = 130 within 4 s, the simulator gone, 0 runner processes and an INTERRUPTED summary. | PASS |
| T-0012-AC4 | Parallel engineer and verifier runs both exit 0, each on its own simulator | `test_T-0012-AC4_parallel_runs_isolated`, `…_default_evidence_dir_is_per_role_and_reset` | Yes. The test asserts both rc = 0, distinct role-specific names and UDIDs, and **overlapping lifetimes** taken from the CREATED_AT/DELETED_AT stamps (69 s in my run), so it can't pass by running the two in sequence. The second test checks that the default dirs are per role. | PASS |
| T-0012-AC5 | Unknown `--runtime` or `--device`: non-zero within 10 s, error names the value, no simulator | `test_T-0012-AC5_bad_runtime_or_device_fails_fast`, `…_fvm_checked_only_when_runner_uses_it`; black-box (b) | Yes. The test asserts rc = 2, under 10 s, the quoted bad value in the output, no `SIMULATOR_NAME=`, an unchanged simulator list and no summary. Black box (b): `--device "iPhone Bogus 3000"` gave exit 2 in 0.14 s, with an error naming the value and the device count unchanged. An unsupported device and runtime pair also gave exit 2 in 0.15 s. | PASS |
| T-0012-AC6 | Cleanup deletes every `mc-*` simulator and nothing else; `--dry-run` deletes nothing | `test_T-0012-AC6_cleanup_only_mc_simulators`, `…_cleanup_fails_loudly_when_listing_fails`; black-box (d) | Yes. In a private device set with one booted and one shut-down `mc-` simulator plus a `zz-` control, the test checks that the dry run deletes nothing (states are compared) and the real run deletes both `mc-` simulators and leaves the control `Shutdown`. On the default set it runs only the dry run and checks that the non-`mc-` UDIDs are unchanged. Black box (d): the default-set dry run listed only my `mc-T-0012-verifier-dryrun`, and the simulator was still there afterwards. | PASS |
| T-0012-AC7 | A screenshot ≤ 1200 px is copied unchanged, not enlarged | `test_T-0012-AC7_small_screenshot_not_upscaled` | Yes. `cmp` checks byte identity at 600 px and at the 1200 px edge, with a control showing that 1800 px is shrunk to 1200 px. An end-to-end run with a stub runner also checks the evidence copy with `cmp`. | PASS |

## Code-review fixes (the 4 important findings)
| # | Finding | Regression test | Fails on pre-fix `a7aefb8`? | Holds on `805b6ab`? | Result |
|---|---|---|---|---|---|
| 1 | `downscale_if_tall` errors ignored, giving phantom summary entries | `test_T-0012-AC1_unwritable_screenshot_is_an_error_not_a_phantom` | **Yes**: the old script exits 0 instead of 4, with the phantom entry | Yes: exit 4, `ERROR (exit 4)`, no `[shot.png]` row, simulator deleted | PASS |
| 2 | A second Ctrl-C during teardown leaks the simulator | `test_T-0012-AC3_teardown_survives_second_sigint_and_kills_orphans` | **Yes**: no "Deleted simulator"; the simulator and 4 orphan processes were leaked (the suite deleted the simulator, and I killed the orphans) | Yes, in the suite and in black box (c) | PASS |
| 3 | Engineer and Verifier runs shared one evidence dir | `test_T-0012-AC4_default_evidence_dir_is_per_role_and_reset` | **Yes**: the old default dir is `<task>`, not `<task>/<role>` | Yes. Per-role dirs; stale `*.png` and `e2e-*.log` removed; `notes.md` kept; a foreign-PNG dir refused with exit 2. In black box (a), the default dir was `documents/evidence/T-0012/verifier`. | PASS |
| 4 | `sim_cleanup.sh` hid listing failures | `test_T-0012-AC6_cleanup_fails_loudly_when_listing_fails` | **Yes**: the old script exits 0 when `simctl` fails | Yes: exit 3 for a failing `xcrun` and for bad JSON, with no "No simulators" message | PASS |

The nits are checked inside these tests (5: `SIMULATOR_DELETED_AT=` asserted after a confirmed delete; 6: the AC5 fvm test; 7: unique names across 3 targets; 9: orphan kill; 10: the interrupted row's log link and partial screenshot). I re-read each nit's code and all of them look correct.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none. Since `a7aefb8`, the only line removed from the suite is the harness ERR trap, which now writes to stderr. That change is harmless and explained in the Log. No assertion was removed or loosened.
- **`|| true` uses (5):** all are in cleanup or tolerance spots and none masks an assertion: the timeout kill and wait in `wait_pid`; `grep -v` returning 1 when nothing matches (the result is asserted empty right after); the second `kill -INT`, after the test has already asserted that the script is alive; and `pkill` just before `fail`.
- **Lint suppressions:** one `// ignore: avoid_print`, in the generated fixture driver (test scaffolding, not project code).
- **Weak spot (not blocking):** the **unit** half of the finding-1 test also passes on the pre-fix code, because sourcing the script inherits `set -e`. The **end-to-end** half is what catches the bug, and it does.

## Visual acceptance (black-box run a)
My own fixture (not the suite's): a counter app tapped 3 times, then a Settings screen.

| Checkpoint | Screenshot | What is visible | Matches? |
|---|---|---|---|
| Launch | `documents/evidence/T-0012/verifier/v01_home_count0.png` | The title "Verifier counter", a large "Count: 0", an "Open settings" button and a "+" FAB at bottom right, on a light peach Material 3 theme. 552×1200. | Yes |
| After 3 taps | `documents/evidence/T-0012/verifier/v02_home_count3.png` | The same screen showing "Count: 3". 552×1200. | Yes |
| Settings | `documents/evidence/T-0012/verifier/v03_settings.png` | "Settings" app bar with a back chevron; "Last count" row showing "3"; a disabled "Dark mode" switch. 552×1200. | Yes |

The summary ([verifier/e2e-summary.md](verifier/e2e-summary.md)) lists the task, role, device, runtime, simulator name and UDID, the PASS row with a link to [verifier/e2e-counter_test.log](verifier/e2e-counter_test.log), and the 3 screenshots, each "downscaled from 1206x2622".

## Issues found
None of these blocks the merge. They are correctness risks to track; I didn't fix any of them.
1. **(low-medium) Run (a)'s target took 370 s**, although its Xcode build took only 14.7 s. It was the first `flutter drive` of a fresh project, so time probably went to dependency or Swift package resolution before the build step (I couldn't tell more, because the log has no timestamps). The script has no per-target timeout (already a follow-up in the task), so a hung runner would block indefinitely. Timestamping log lines would help diagnose this.
2. **(low) The evidence-dir reset deletes every `*.png`** in any dir that holds an `e2e-summary.md` written by this script. Repro: put a hand-made `foo.png` into `documents/evidence/T-0012/verifier/` and re-run, and it is deleted. This is documented, but `--evidence-dir documents/evidence/<task>` (the old layout, where the Verifier's report screenshots live) would delete those screenshots.
3. **(low) Two runs with the same task and role** (for example, a re-dispatched Verifier while the first is still running) share the default dir and clobber each other's outputs. The simulators stay separate.
4. **(low) SIGHUP is not trapped.** A probe on bash 3.2 showed that the EXIT trap still runs on SIGHUP (rc 129), so cleanup happens, but the summary says `ERROR (exit 129)` and a second HUP during teardown isn't ignored.
5. **(low) The orphan-name pre-flight check** (`udids_named` in `preflight_simulator`) treats a failed simulator listing as "no clash". That's harmless, because the name contains the pid.
6. **(info)** The new suite run against the pre-fix scripts leaks orphan processes when finding 2's test fails (it fails before reaching its `pkill`). This only matters for the kind of check I ran here.

## Notes for the Tech Lead
- Both suite runs completed: run 1 finished before the session pause, so it hadn't died, and run 2 was re-run in the foreground as asked. The suite has no flaky tests in 2 runs.
- Cleanup: all simulators I created are gone. `xcrun simctl list devices | grep -E "mc-|zz-T-0012"` prints nothing. I also removed my fixture's leftover SwiftPM `*.lock` in `$TMPDIR`, plus the temp dir and 4 orphans left by the deliberate pre-fix run.
- Evidence: `verifier/` (run a, written by the script), [verifier-test-suite.txt](verifier-test-suite.txt) and [verifier-blackbox.txt](verifier-blackbox.txt).
