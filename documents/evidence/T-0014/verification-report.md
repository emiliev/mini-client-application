# Verification report — T-0014: Toolchain bring-up under Bazel (P3-01)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** round 1 `fleet/T-0014-toolchain` @ `eba44d8`; **round 2 (this verdict) @ `d29ee32`**, the fix commit on top of `eba44d8` (verified on `fleet/T-0014-verify2`)
- **Simulators:** round 1 `mc-T-0014-verifier`, round 2 `mc-T-0014-verifier-5874`. Both iPhone 17 Pro, iOS 26.2, created and deleted by the Verifier. `xcrun simctl list devices | grep mc-` is empty at the end.
- **Bazel:** `tool/bazelw` → bazelisk 1.29.0 → `Build label: 9.3.0`. Round 1 used output base `/tmp/mc-verify-t0014`; round 2 used the worktree's own default output base plus throwaway ones. Every server was shut down at the end. Flutter 3.47.7, Dart 3.13.5.
- **Verdict:** **PASS** at `d29ee32`. All 8 ACs pass again, and every review fix holds except one: the profile config's trace and memory profile paths are broken (R2-1, medium, not covered by an AC).

## Round 2: re-verification at `d29ee32`
Evidence is in [`verifier2/`](verifier2/). Every check ran from this worktree.

| Item | Result | Evidence |
|---|---|---|
| F-0012 number | No collision. `origin/main` has F-0001 to F-0005 and F-0008; the branch has F-0006 to F-0011. No branch has an F-0012 | `git ls-tree` |
| `T-0014-AC1_sim_launch.sh --role verifier` | PASS. It builds, finds the IPA through `cquery`, then creates, launches and **deletes** `mc-T-0014-verifier-5874`. I viewed the screenshot: the same UI as round 1 ("Tap + to start", "initial", Details, the + button, DEBUG banner), with the system "Apple Intelligence" banner over the app bar | [`T-0014-AC1.md`](verifier2/T-0014-AC1.md), [`ac1-launch-sim.png`](verifier2/ac1-launch-sim.png) |
| AC2 `test --nocache_test_results //spike/hello:widget_test` | PASS, 3/3 cases | [`ac2-widget-test.log`](verifier2/ac2-widget-test.log) |
| `T-0014-AC3_koutline_cutoff.sh` | PASS. Both `.koutline` digests unchanged, `.kmod` changed, 0 fallback lines. Its grep covers both strippers' messages (both end "falling back to unstripped dill"). The source was restored | [`T-0014-AC3.md`](verifier2/T-0014-AC3.md) |
| `T-0014-AC4_cfgdup_count.sh` | PASS. Throwaway output base, cold. Its counts equal my round-1 independent counter exactly (codegen 3/3, kernel 1 exact, 12/32 targets). The sim build still has 3450 processes and no DartAnalyze, so the global `build --aspects` adds no actions | [`T-0014-AC4.md`](verifier2/T-0014-AC4.md) |
| `T-0014-AC5_fvm_version.sh` | PASS (3.47.7) | [`T-0014-AC5.md`](verifier2/T-0014-AC5.md) |
| `T-0014-AC7_codegen_matches_build_runner.sh` | PASS. Both files EQUAL. The `--summary` counts come from `aquery` and aren't vacuous (freezed 4, routes 0), and all 6 pattern methods are present | [`T-0014-AC7.md`](verifier2/T-0014-AC7.md) |
| `T-0014-AC8_configs_parse.sh` | PASS. It now runs a **real** `build --config=lint //spike/...` and `dart format`. **Negative control:** with `pages.dart` deliberately unformatted, the check FAILS on both rows (then restored) | [`T-0014-AC8.md`](verifier2/T-0014-AC8.md), [`ac8-negative-control.md`](verifier2/ac8-negative-control.md) |
| `spike_reference.sh` | It builds every `dart_codegen` target with `--remote_download_all`, adds `greeting` as a first-party path dep (in both `dependencies` and `dependency_overrides`), checks hosted versions against the overlay lock, and checks for unresolved imports. See R2-2 | AC7 log |
| `--config=lint` on the committed tree | PASS. A cold run (3972 processes) ran DartAnalyze and DartFormat on all 4 first-party targets (`greeting`, `_stage`, `hello_lib`, `widget_test`), all exit 0 | [`lint-cold.log`](verifier2/lint-cold.log), [`lint-actions.txt`](verifier2/lint-actions.txt) |
| `test --config=lint` | Analysis completes with 0 duplicate-aspect lines (AC8 row) | AC8 |
| `tool/bazelw --budget16` after a startup option | Fixed. `tool/bazelw --output_base=/tmp/… --budget16 build --nobuild //spike/greeting` exits 0, and `info max-heap-size` = 3221 MB. `tool/test/bazelw_test.sh`: 8 passed, 0 failed | [`bazelw-budget16-startup-first.log`](verifier2/bazelw-budget16-startup-first.log) |
| Profile paths per worktree | **Partly broken (R2-1).** Only the execution log lands at `<worktree>/bazel-mc-exec.log.zst` | [`profile-config.log`](verifier2/profile-config.log) |

### Round 2 issues
- **R2-1 (Medium) `--config=profile` writes no trace profile and no memory profile.** `%workspace%` is not expanded for `--profile` or `--memory_profile`. Bazel resolves them literally, as `<worktree>/%workspace%/bazel-mc-profile.json.gz`, and prints `ERROR: Error while creating profile file … (No such file or directory)` (the same for `bazel-mc-mem.txt`). The build still **exits 0**, so the AC8 parse row (which matches only option errors) cannot see it. `--execution_log_compact_file` is expanded and works. Repro: `tool/bazelw build --config=profile //spike/greeting`, then `ls bazel-mc-*` shows only the exec log. Fix: use plain relative paths (`--profile=bazel-mc-profile.json.gz`), which the error shows resolve against the workspace, or let the P4 harness pass absolute paths. Then extend AC8 to assert the files exist. This matters to T-0016 / P4.
- **R2-2 (Low) `spike_reference.sh` step 1 hides a Bazel build failure.** `… | grep -a -E '^(ERROR|INFO: Build completed)' || true` discards the exit code, and the grep matched nothing in my run, perhaps because of colour codes. A failed codegen build would therefore fall through to comparing whatever is left in `bazel-bin`, which may be stale. Fix: check `${PIPESTATUS[0]}`, or run the build without the filter.
- Round-1 issues 1 (lint red), 3 (`--budget16` parsing) and 4 (profile `/tmp` collision) are fixed; for 4, see R2-1. Issue 2 is F-0012, now with a status note. Issue 5 is resolved by the ID-named `tool/checks/`.

---

# Round 1 (at `eba44d8`, kept for the record)

## Gates re-run independently
This is a toolchain spike: there is no app code under `lib/` and no `tool/verify.sh` yet. These are the gates that apply.

| Gate | Command | Result |
|---|---|---|
| Clean cold sim build | `tool/bazelw --output_base=… clean`, then `build --config=sim --config=cold //spike/hello:hello_ios` | PASS. 3450 processes, 0 cache hits, 32 s ([log](verifier/ac1-ac4-build-sim-cold.log)) |
| Cold test (analyze + format aspect) | `test --config=cold //spike/hello:widget_test` | PASS. 3/3 cases ([log](verifier/ac2-ac4-widget-test-cold.log), [test.log](verifier/ac2-widget-test.test.log)) |
| Format | `fvm dart format --output=none --set-exit-if-changed spike` | **FAIL**: `spike/hello/lib/src/pages.dart` changed (issue 1) |
| Lint | `tool/bazelw build --config=lint --keep_going //spike/...` | **FAIL**: DartFormat on `_stage` and `hello_lib` (pages.dart). DartAnalyze is clean ([log](verifier/lint-spike.log)) |
| Lockfile | `git status` after every build | `MODULE.bazel.lock` unchanged |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0014-AC1 | sim build on 9.3.0, launch on a private sim | [`ac1-launch-sim.png`](verifier/ac1-launch-sim.png), [`ac1-launch.log`](verifier/ac1-launch.log), [`ac1-launch.sh`](verifier/ac1-launch.sh) | Yes. A cold build after `clean`, then I installed the IPA from my own output base. `simctl launch` returned a PID and the app was still in `launchctl` after 15 s | PASS |
| T-0014-AC2 | widget test passes with the analyze aspect | `T-0014-AC2 hello app renders and counts under Bazel` | Yes. It renders the greeting, taps `+`, and checks `Count: 1`. One DartAnalyze and one DartFormat ran, but only on `widget_test` itself (F-0012) | PASS |
| T-0014-AC3 | Dart version, `.koutline` byte-identical after a body edit, no stripper fallback | [`ac3-h-sdk.txt`](verifier/ac3-h-sdk.txt), [`ac3-h-sdk.sh`](verifier/ac3-h-sdk.sh), digests [before](verifier/ac3-digests-before.txt) / [after](verifier/ac3-digests-after.txt) | Yes. My own body edit (`final n = who.length; assert(n > 0);`), different from the Engineer's, ran under `--config=cold` so the kernels really recompiled. `greeting.flutter.koutline` and `greeting.koutline` kept the same sha256 per file. Both `.kmod/0.dill` changed. The edit was reverted (`git diff` empty). `dart-sdk/version` = 3.13.5. 0 `falling back to unstripped` / `unsupported kernel format` lines in build or worker logs | PASS |
| T-0014-AC4 | count Dart actions duplicated across configs | [`ac4-count-dup.txt`](verifier/ac4-count-dup.txt) from my own counter [`count_dup.py`](verifier/count_dup.py) (I did not use the Engineer's `cfgdup.py`) | Yes. One server, `clean`, then a cold sim build and a cold host test, each with `--execution_log_json_file`. **DartCodegen 3/3 duplicated**, DartKernel 1 exact duplicate (`//spike/greeting`), 12 of 32 non-exec kernel targets in two configurations, DartAnalyzerSummary 4 of 30. This matches the Engineer's numbers exactly | PASS |
| T-0014-AC5 | `fvm flutter --version` = 3.47.7 | [`ac5-fvm-flutter-version.txt`](verifier/ac5-fvm-flutter-version.txt) | Yes. `Flutter 3.47.7 … Dart 3.13.5` from the repo root (`.fvmrc`) | PASS |
| T-0014-AC6 | freezed `when`/`maybeWhen`/`map` on a private-case union, and `state.when` compiles | `T-0014-AC6 state.when / maybeWhen / map on a private-case union`; `bazel-bin/…/counter_state.freezed.dart` | Yes. The generated `extension CounterStatePatterns` has `maybeMap` :59, `map` :83, `mapOrNull` :103, `maybeWhen` :126, `when` :149 and `whenOrNull` :168, over private `_Initial`/`_Counting`/`_Failed`. `pages.dart` uses `_state.when` and it compiles in the app and the test. I regenerated the build_runner reference: **EQUAL**, sha256 `cab0d955…7489` | PASS |
| T-0014-AC7 | go_router `.g.dart` over real go_router 17.5.0 compiles and equals build_runner's | `T-0014-AC7 generated $appRoutes navigates to the typed DetailRoute`; [`ac6-ac7-spike-reference.log`](verifier/ac6-ac7-spike-reference.log) | Yes. I re-ran `tool/build_runner_overlay/spike_reference.sh spike/hello` against my output base (through an `MC_BAZELISK` wrapper). build_runner wrote 3 outputs, and `routes.g.dart` is **EQUAL**, sha256 `9c1849aa…bb29`. The lock has go_router 17.5.0 and the overlay has go_router_builder 4.5.0. It passes only with the F-0007 workaround, and the stock crash is recorded as a finding, as the AC requires | PASS |
| T-0014-AC8 | lint, ci+cold and budget16 parse; nothing unknown | [`ac8-configs-parse.md`](verifier/ac8-configs-parse.md), [`ac8-configs-parse.sh`](verifier/ac8-configs-parse.sh) | Yes. `lint`, `ci`+`cold`, `budget16`, `budget16_8c`, `profile`, `remote-cache`, `sim`, `device-profile` and `tool/bazelw --budget16` all exit 0 with 0 unknown-option lines. Negative controls: an undefined config gives exit 2 (`Config value 'bogus_verifier_cfg' is not defined`), and an unknown flag gives exit 2 (`Unrecognized option`). `test --config=app` exits 1 only because no test is tagged `app`. `--config=device` on `hello_ios` parses, but analysis fails with no provisioning profile, which is expected (X8) and not in the AC | PASS |

## F-0007 (go_router codegen crash): verdict
**The root cause is correct, it is a real upstream integration bug, and the workaround is sound.** I checked it against the rules source fetched at the pinned commits, in my output base's `external/`:
- `ai_rules_dart+/dart/private/dart_codegen.bzl:124-135` (`_covered_summary_keys`) turns summaries off only when `embedder_in_closure(d[DartInfo])` holds. That check (`dart_analyzer_summary.bzl:120-137`) looks for a `sky_engine` package or a `lib/_embedder.yaml` resource in `DartInfo` only.
- `ai_rules_flutter+/flutter/private/flutter_library.bzl:575-609` and `:715-730` show that `flutter_library` deliberately builds `DartInfo` from `ctx.attr.deps` alone. It adds `_sky_engine` only to `DartAnalyzableInfo`. `@pub_deps//:flutter` is a plain `flutter_library` whose deps don't include sky_engine, so the guard can never fire for a Flutter closure. Each rule set behaves as designed, and the bug is in how the two fit together.
- **Independent repro:** I removed the `sky_engine` line temporarily. `aquery` then showed **12** `--summary` args on `routes_go_router_part` (0 with the line), and a cold build crashed with the same `Null check operator … bundle_reader.dart:418:52` / "Worker process did not return a WorkResponse" ([`f0007-repro.txt`](verifier/f0007-repro.txt), [log](verifier/f0007-repro-build.log)). I restored the file and the build passed again.
- **Workaround:** the `@flutter_sky_engine//:sky_engine` dep makes the existing guard fire for that one action. That is the behaviour plan 03 KD6 expected. The Flutter-free `counter_state_freezed` keeps its 4 summaries ([`ac7-summaries-per-action.txt`](verifier/ac7-summaries-per-action.txt)). The output is byte-identical to build_runner's, and the extra dep changes only the codegen action's package map, not any compile input. The workaround is sound, but every codegen over Flutter must remember it, so `buildgen` / `mc_codegen` has to emit it (the Engineer already listed this follow-up).

## Hygiene
- `git diff --name-only c2f4f2b..eba44d8` contains no `*.g.dart`, `*.freezed.dart`, `bazel-*`, `.dart_tool/`, `.fvm/`, `build/` or Flutter ephemeral or registrant files, and no IPA, dill or kmod. The largest new files are `MODULE.bazel.lock` (589 KB, expected under bzlmod and needed for `--lockfile_mode=error` in `ci`) and one 95 KB PNG (552×1200). The 1772-line cold-build log from the WIP commit was removed in `3c001a9`. `.gitignore` covers `bazel-*`, `.dart_tool/`, `.fvm/` and generated Dart.
- `MODULE.bazel` matches ADR-0008: `ai_rules_dart` `e7163aab8f9171f54693cd1b99feb7d3cee9602d`, `ai_rules_flutter` `876e263d65ca3eb33e4b05f9b0dc55affc5b3887`, Flutter 3.47.7, rules_apple 5.2.0, rules_swift 4.1.2, apple_support 2.9.1. `.bazelversion` is 9.3.0 and `.fvmrc` is 3.47.7.
- Every `common`/`build`/`test` line in `.bazelrc` is identical to the plan 03 §1.4 block (diffed mechanically). The root pubspec and lock hold no generator or build_runner (R10), and the overlay pins analyzer 14.5.0 / source_helper 1.3.13 as F-0011 says.
- The Engineer changed only their task file, new findings, evidence and in-scope files, with no edits to TL-owned files.

## Test-integrity audit
- Tests deleted, skipped or weakened: none. `widget_test.dart` grew from 2 to 3 cases, and each AC test asserts real behaviour.
- Lint suppressions added: none. `analysis_options.yaml` is new, with no `// ignore:`.
- Golden files updated: none.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| AC1 launch | [`verifier/ac1-launch-sim.png`](verifier/ac1-launch-sim.png) (552×1200, downscaled from 2622) | The Bazel-built Flutter app on iPhone 17 Pro: "Tap + to start", "initial" (from `state.when`/`map`), a "Details" button, a `+` FAB, and the DEBUG ribbon. A system "Ready for Apple Intelligence" notification covers the app bar (F-0009 gotcha 5). That is not an app defect | Yes |

## Issues found
1. **(Medium) `--config=lint` is red on the committed tree.** `spike/hello/lib/src/pages.dart` is not formatted for Dart 3.13.5: the formatter wants a blank line between `import 'counter_state.dart';` and `import 'package:greeting/greeting.dart';`. Repro: `fvm dart format --output=none --set-exit-if-changed spike` (or `tool/bazelw build --config=lint --keep_going //spike/...`, where DartFormat fails on `//spike/hello:_stage` and `//spike/hello:hello_lib`). The Engineer's `lint-spike.log` is stale: it shows "Analyzed 6 targets", while the final tree has 7. Neither AC2 (format only on `widget_test`) nor AC8 (parse only) catches it. Fix: run `fvm dart format spike` (or put the package import first, as dart convention does).
2. **(Low) Gotcha: `bazel test` gates only the test target's own sources.** The output groups come only from top-level targets, so under `test` the libraries get no analyze or format check. Recorded as **F-0012** (a new finding draft; renumber it if it collides). CI and `verify.sh` need `build --config=lint //...` as well.
3. **(Low) `tool/bazelw --budget16` breaks when there is any startup option.** The script takes `args[0]` as the command, so `tool/bazelw --budget16 --output_base=/x build …` fails with `FATAL: Unknown startup option: '--config=budget16'`. Repro: the command above. This matters for P4, which may want separate output bases.
4. **(Info)** `build:profile` writes to fixed `/tmp/mc-*.json.gz`, `/tmp/mc-exec.log.zst` and `/tmp/mc-mem.txt`, so parallel crew profiling in different worktrees would overwrite each other. P4 / T-0016 should take a per-run path.
5. **(Info)** The AC3/4/5/8 checks are measurement ACs. They are backed by evidence scripts, not by tests with the AC ID in their names (ADR-0006 §1 asks for a test or a screenshot). That is acceptable for a spike, but the TL may want to note the exception.

## Notes for the Tech Lead
- I reproduced every number the Engineer claimed: the codegen sha256s, the AC4 duplicate counts, the outline identity, and the F-0007 crash signature.
- Fix issue 1 before or at merge. It is a one-line formatter change, and AC2 / AC6 / AC7 are unaffected.
- Pending-work candidates: issue 3 (bazelw argument parsing), issue 4 (profile paths), and the F-0012 CI implication.
- Output base `/tmp/mc-verify-t0014` (server shut down) can be deleted. Exec logs (40 MB) were kept in scratch, not committed.
