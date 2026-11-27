# Verification report — T-0055: `tool/e2e_ios.sh` must fail a target whose app did not build

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0055-e2e-false-pass` @ `5d8f6f5`
- **Simulator:** `mc-T-0055-verifier-<pid>` (one per script run, iPhone 17 Pro, iOS 26.2), created and deleted by the script each time. `simctl list` at the end shows no `mc-T-0055-verifier-*`.
- **Verdict:** **PASS**

Scratch project: `prepare_pub_project.sh` copy of `app/mini_client` at `5d8f6f5`, plus throwaway targets `zz_good`, `zz_broken` (type error), `zz_fail` (runtime `expect(1,2)`), `zz_missingimport` (unknown package), `zz_syntax` (missing `;`). Generator: `evidence/T-0055/verifier/mk.sh`. All evidence is under `documents/evidence/T-0055/verifier/<run>/` (summary, `run.out`, per-target logs).

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Script tests | `tool/test/e2e_ios_test.sh` | 20 passed, 0 failed (`e2e_ios_test-full-suite.txt`) |
| L0 / Bazel `test //...` | not re-run | The diff touches only a shell script, its shell tests, docs and evidence. No Dart or BUILD file changed. The shell suite is the relevant gate. `shellcheck` is not installed (as the engineer said). |
| L4 E2E | real script on own simulator, see below | PASS |

## Acceptance criteria
| AC | Scenario (short) | Verifier's own run | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0055-AC1a | Compile error after a good target is FAIL, reason "build failed" | Old `origin/main` script (`old/`): good, then broken gives `RESULT: PASS (2)`. The broken log shows `flutter: ... +0: zz_good_test ran` (the other target's test) and `# exit code: 0`. This is the false PASS, reproduced. Fixed script (`a/`): good PASS, broken `FAIL (build failed: BUILD FAILED)`, `RESULT: FAIL (2 of 4)`, exit 1. | yes: `test_T-0055-AC1_good_pass_runtime_fail_build_fail` checks the summary rows | PASS |
| T-0055-AC1b | Broken target alone is FAIL | `c/`: `FAIL (build failed: BUILD FAILED)`, exit 1 | yes (same test, "broken alone") | PASS |
| T-0055-AC1c | Runtime failure is still FAIL | `a/`: `zz_fail` is plain `FAIL` (exit 1, not mislabelled as a build failure) | yes | PASS |
| T-0055-AC1d | Good target is PASS | `a/` (twice, the second after a failure), `reg/` | yes | PASS |
| T-0055-AC1e | Each defence alone | `d1only/` (marker scan disabled in a scratch copy, line 762): broken `FAIL`, runner exit 1, log "Application failed to start. Will not run test". `d2only/` (stale delete and uninstall disabled): broken `FAIL (build failed: BUILD FAILED)`, with the log showing `# exit code: 0`. | run logs (no test; the task says run logs) | PASS |
| T-0055-AC2 | Script tests, marker with exit 0 is FAIL | 20 of 20. 4 `T-0055-AC1` and 3 `T-0055-AC2` tests exist (one more AC2 than asked). With the marker scan disabled at the call site, `AC1_good_pass_runtime_fail_build_fail` and `AC2_fake_runner_printing_a_marker_with_exit_0_is_fail` go red (`mutation-marker-scan-off.txt`, 5 pass / 2 fail). | see the note on `AC2_every_marker...` below | PASS |
| T-0055-AC3 | Re-baseline | Not repeated in full (the brief asks for at least 3 real targets). `characters_journey_test`, `comic_deeplink_test` and `analytics_screens_test` are PASS (`reg/`). The engineer's 11 of 11 is in `engineer/rebaseline/`. | n/a | PASS (sampled) |
| T-0055-AC4 | Gates, finding, README | F-0055 and README e2e section exist and match the code. `shellcheck` unavailable, reported honestly. | n/a | PASS |

## Review items
| Item | Check | Result |
|---|---|---|
| Recovered launch retry | Fake runner: `Application failed to start on attempt: 1`, then `All tests passed!`, exit 0 (`retry/`) | PASS. Same text plus `Could not build the application` gives FAIL (`real/`). |
| Build dir kept | Real script with fake runners: a runner with `flutter drive` deletes `build/ios/iphonesimulator`. With `--keep-build`, `--use-application-binary` or `--no-build` the dir is kept (`kplain`, `kkeepflag`, `kappbin`, `knobuild`) | PASS |
| Sentinel | Runner command text containing `BUILD FAILED Error (Xcode)` gives PASS (`sentinel/`) | PASS |
| Uninstall log line | Unit test `bundle_id_resolution` (fake `simctl` failing) passes. Real run: the line is "uninstalled <id>" when `simctl` exits 0. See nit 1. | PASS (nit) |
| Bundle id | Real runs log `uninstalled com.emiliev.miniClient` (Debug config). The `$(VAR)` refusal is covered by `test_T-0055-AC1_bundle_id_resolution` (passes). | PASS |

## Marker coverage: real breakage on the simulator
Every kind below was run after a good target, or alone, with the real `flutter drive`.

| Breakage | Result |
|---|---|
| Type error in the test file (`zz_broken`) | FAIL, `BUILD FAILED` |
| Missing package import in the test file (`zz_missingimport`) | FAIL, `BUILD FAILED` (`b/`) |
| Syntax error in the test file (`zz_syntax`) | FAIL, `BUILD FAILED` (`b/`) |
| Compile error in a `lib/` file, reached by `analytics_screens_test` (`d/`) | FAIL, `BUILD FAILED` |
| Xcode project error (`IPHONEOS_DEPLOYMENT_TARGET = 99.0`, `e/`) | FAIL, `Could not build the application`. The log says "No Xcode build settings have been found". The runner exit code was 1 here, so the marker was not the only thing catching it. |

No real build output got past the markers. Not tried: CocoaPods and code-signing failures (they need a different project state). Both print `Could not build the application` or `Failed to build iOS app` through Flutter, per the before-fix log, so I expect them to be covered, but this is not proven.

## Test-integrity audit
- The diff of `tool/test/e2e_ios_test.sh` has no removed lines. Only the new `T-0055` tests and helpers (`t55_` prefix) are added. No existing case is weakened, skipped or edited.
- Lint suppressions added: none.
- Golden files updated: none.
- `git diff origin/main...5d8f6f5 --stat` outside evidence: `tool/e2e_ios.sh`, `tool/test/e2e_ios_test.sh`, `tool/README.md`, F-0055 and the task file. That is the expected set.
- No helper leaks: the full suite passes with the new tests in the list, and the suite's own `mc-T-0012-*` simulators were all cleaned up.

## Visual acceptance
Not a UI task. The engineer's re-baseline screenshots are in `engineer/rebaseline/`. I did not re-capture them.

## Issues found
No blocking defects. Nits:
1. (nit) `tool/e2e_ios.sh`, `remove_stale_app`: the log says `uninstalled <id>` whenever `simctl uninstall` exits 0. `simctl` exits 0 even when the app is not installed, so `--bundle-id com.no.such.app` logs "uninstalled com.no.such.app" (`badid/`). The line is true only in the sense "simctl succeeded". Cosmetic.
2. (nit) `test_T-0055-AC2_every_marker_is_found_in_a_log` still passes when the marker scan is disabled at the call site, because it tests `build_failure_marker` as a function. The two tests that go through the real script do go red, so the property is covered. This test only covers the list.
3. (nit) The `$(VAR)` refusal and the failing-`simctl` path are covered only by the unit test. I did not exercise them through the real script.

## Notes for the Tech Lead
- The engineer's key claim holds, and I re-derived it: `flutter drive` exits 0 after a failed build and runs the previous target's stale app. Deleting `build/ios/iphonesimulator` plus the marker scan fix it, and each works alone.
- The Verifier's `T-0055` tests need `tool/test/e2e_ios_test.sh T-0055` (pattern argument) to run in about 2.5 minutes. The full suite takes about 12.5 minutes.
- I saw `mc-T-0056-engineer-*` on the machine once and left it alone. It was gone by the end.
- Scratch copies of the script used for the AC1e runs are not committed. Their one-line differences are described in the AC1e row.
