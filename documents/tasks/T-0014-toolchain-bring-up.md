# T-0014: Toolchain bring-up under Bazel (P3-01, spike S1)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-23; Verifier PASS `c2dbcee`) |
| Owner | crew: Engineer (Opus, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0014-toolchain` |
| Created | 2026-11-23 |
| Depends on | — (Phase A, wave A1) |
| Related | [plan 03 §1, §2, §4.5, §8, P3-01](../plan/03-bazel-integration.md), ADR-0008, R16, R18, R28, V3-01 |

## Goal
Prove the pinned toolchain works end to end on this Mac: a Flutter iOS hello-world built and tested by Bazel with `ai_rules_dart` `e7163aa` and `ai_rules_flutter` `876e263`, on Flutter 3.47.7 and Bazel 9.3.0. Also settle the two codegen unknowns: freezed `when` (R16) and go_router_builder over a Flutter closure (V3-01).

## Scope
- **In:** `MODULE.bazel`, `.bazelrc` (configs `sim`, `lint`, `ci`, `cold`, `budget16`, `profile`, `remote-cache`, following plan 03 §1), `.bazelversion`, `REPO.bazel`, `tool/bazelw`, `.fvmrc` (3.47.7), `spike/hello/` (app, widget test, freezed union, one `@TypedGoRoute` file), the build_runner overlay used only to produce reference outputs, and the `.gitignore` entries.
- **Out:** patch queue (T-0015+ / P3-02), unsupported shims (P3-03 to P3-05), real packages.
- **Files / areas:** repo root Bazel files, `tool/bazelw`, `spike/`.

## Acceptance criteria
- **T-0014-AC1:** Given a clean clone, when `tool/bazelw build --config=sim //spike/hello:hello_ios` runs, then it succeeds on Bazel 9.3.0 and the app launches on a private `mc-T-0014-*` simulator via `tool/e2e_ios.sh` or `simctl` (screenshot in evidence).
- **T-0014-AC2:** Given the same, when `tool/bazelw test //spike/hello:widget_test` runs, then it passes with the analyze aspect on.
- **T-0014-AC3:** Then the evidence records the bundled Dart version, a `.koutline` that stays byte-identical after a body-only edit, and no stripper-fallback diagnostic (H-SDK).
- **T-0014-AC4:** Given the sim build and a host test in one server, then the execution log counts any `DartKernel` or `DartCodegen` actions duplicated across configurations (H-CFGDUP), and the evidence records the count.
- **T-0014-AC5:** `fvm flutter --version` inside the repo reports 3.47.7.
- **T-0014-AC6:** Given a freezed union with private cases, when built with the stock freezed shim, then the `.freezed.dart` contains `when`/`maybeWhen`/`map` and a widget calling `state.when` compiles. Otherwise the `switch` fallback is recorded (R16).
- **T-0014-AC7:** Given one `@TypedGoRoute` file over real go_router 17.5.0 in a Flutter closure, when built with the stock go_router shim, then the `.g.dart` compiles and equals build_runner's output from the overlay. If it doesn't, the failure is recorded as a finding and go_router_builder joins the R28 fallback (V3-01).
- **T-0014-AC8:** Given `--config=lint`, `--config=ci --config=cold` and `--config=budget16`, when each parses (`tool/bazelw build --nobuild //spike/...`), then Bazel reports no unknown option or config.

## Log
- 2026-11-23: Created and dispatched (wave A1).
- 2026-11-23 (Engineer): Found bazelisk 1.29.0 installed but unlinked at `/opt/homebrew/opt/bazelisk/bin/`; `tool/bazelw` uses it (F-0006). Installed Flutter 3.47.7 with `fvm install 3.47.7`; FVM's global is unchanged. No other installs.
- 2026-11-23 (Engineer): Wrote the workspace files (`MODULE.bazel`, `.bazelrc` copied from plan 03 §1.4, `REPO.bazel`, `.bazelversion`, `.fvmrc`, root `BUILD.bazel` + `analysis_options.yaml`), the root pub workspace and `spike/hello`. The cold first build took 893 s, mostly fetching, and **failed**: the go_router shim crashed with an analyzer null-check, because summaries were passed over a Flutter closure (F-0007).
- 2026-11-23 (Engineer): Usage-limit pause; WIP commit `1193bcb`.
- 2026-11-23 (Engineer): Fixed the crash with the `@flutter_sky_engine//:sky_engine` dep on route codegen (F-0007). Set `language_version = "3.13"` so the shims format like build_runner (F-0011). Pinned `analyzer` and `source_helper` in the overlay (F-0011). Moved `greeting` into its own package `spike/greeting`, because a same-package library has no outline (F-0009). Ran every AC; findings F-0006, F-0007, F-0009, F-0010 and F-0011.
- 2026-11-23 (Engineer): Rebased onto `origin/main` `c2f4f2b`. Renamed my F-0008 to **F-0011**, because `main` already has F-0008 from T-0016. Merged `.gitignore` with main's entries (`bazel-*`, `coverage/`). The warm `--config=sim` build still passes.
- 2026-11-23 (Engineer): Code-review fix round on top of `eba44d8` (the Verifier passed `eba44d8` but found `--config=lint` failing on unformatted `pages.dart`, and also hit the `--budget16` and `/tmp` profile-path bugs).
  - (1) The evidence scripts are replaced by portable `tool/checks/T-0014-ACn_*.sh` (repo from `git rev-parse`, scratch from `mktemp`).
  - (2) `spike_reference.sh` builds the codegen targets itself with `--remote_download_all`.
  - (3) The overlay adds first-party workspace deps as path deps, checks lock drift and fails on unresolved imports.
  - (4) `tool/bazelw` finds the command after the leading startup options, matches `--budget16` only there, and no longer `cd`s; covered by `tool/test/bazelw_test.sh`.
  - Nits:
    - The analyze aspect is added once (`test --config=lint` used to fail).
    - `--config=profile` paths use `%workspace%`.
    - `build/` is anchored in `REPO.bazel`.
    - The unused `Runner-Bridging-Header.h` and `LaunchImage.imageset` are deleted (`flutter_ios_app` reads neither).
    - `pages.dart` is formatted.
    - AC8 now runs the real lint build plus `dart format --set-exit-if-changed`.
  - Re-ran every check: all pass.

## Outcome
**Done: all 8 ACs pass on Bazel 9.3.0 / Flutter 3.47.7 (Dart 3.13.5).** V3-01 is settled: go_router_builder stays Bazel-native, but every codegen action over a Flutter closure needs the `sky_engine` dep until rules_dart or rules_flutter fixes the embedder guard (F-0007). R16 holds: freezed emits `when`/`maybeWhen`/`map`.

Every AC has an ID-named, repeatable check (ADR-0006). Each `tool/checks/T-0014-ACn_*.sh` derives the repo from `git rev-parse`, uses `mktemp` for scratch, exits 0 for PASS, and takes `--out FILE` (and `--role` for AC1). AC2, AC6 and AC7 are also test-case names in `//spike/hello:widget_test`.

| AC | Result | Check | Evidence |
|---|---|---|---|
| T-0014-AC1 | PASS. The sim build produces `hello_ios.ipa` (warm about 24 s; cold 893 s, mostly fetch). It launches on a private `mc-T-0014-<role>-<pid>` iPhone 17 Pro / iOS 26.2 simulator, which is always deleted | `tool/checks/T-0014-AC1_sim_launch.sh` | [`T-0014-AC1.md`](../evidence/T-0014/engineer/T-0014-AC1.md), [`ac1-launch-sim.png`](../evidence/T-0014/engineer/ac1-launch-sim.png), [`ac1-build-sim.log`](../evidence/T-0014/engineer/ac1-build-sim.log) |
| T-0014-AC2 | PASS. 3 cases pass with the analyze and format aspects on (uncached run) | test `T-0014-AC2 hello app renders and counts under Bazel` | [`ac2-widget-test.log`](../evidence/T-0014/engineer/ac2-widget-test.log) |
| T-0014-AC3 | PASS. Dart 3.13.5. After a body-only edit, `greeting.flutter.koutline` and `greeting.koutline` are unchanged and `.kmod` changed. 0 stripper-fallback lines | `tool/checks/T-0014-AC3_koutline_cutoff.sh` | [`T-0014-AC3.md`](../evidence/T-0014/engineer/T-0014-AC3.md) |
| T-0014-AC4 | PASS (measured, reproduced on a fresh output base). DartCodegen duplicated 3/3; DartKernel 1 exact duplicate, and 12/32 targets compiled as two variants | `tool/checks/T-0014-AC4_cfgdup_count.sh` (+ `cfgdup.py`) | [`T-0014-AC4.md`](../evidence/T-0014/engineer/T-0014-AC4.md), F-0010 |
| T-0014-AC5 | PASS. `fvm flutter --version` in the repo reports 3.47.7 | `tool/checks/T-0014-AC5_fvm_version.sh` | [`T-0014-AC5.md`](../evidence/T-0014/engineer/T-0014-AC5.md) |
| T-0014-AC6 | PASS. A private-case sealed union gets `when`/`maybeWhen`/`map` (+`maybeMap`, `whenOrNull`, `mapOrNull`), and its output is byte-identical to build_runner's | test `T-0014-AC6 …`; `tool/checks/T-0014-AC7_codegen_matches_build_runner.sh` | [`T-0014-AC7.md`](../evidence/T-0014/engineer/T-0014-AC7.md), [`ac6-ac7-codegen.md`](../evidence/T-0014/engineer/ac6-ac7-codegen.md) |
| T-0014-AC7 | PASS with the F-0007 workaround. `routes.g.dart` is byte-identical to build_runner's; the route codegen gets 0 `--summary` args. The stock first-run crash is recorded | test `T-0014-AC7 …`; `tool/checks/T-0014-AC7_codegen_matches_build_runner.sh` | [`T-0014-AC7.md`](../evidence/T-0014/engineer/T-0014-AC7.md), [`ac6-ac7-codegen.md`](../evidence/T-0014/engineer/ac6-ac7-codegen.md), [`ac7-first-cold-build-crash.log`](../evidence/T-0014/engineer/ac7-first-cold-build-crash.log) |
| T-0014-AC8 | PASS. 11 config invocations parse (including `test --config=lint`, which failed before the fix), and the negative control fails. `build --config=lint //spike/...` **really runs** and passes, and `dart format --set-exit-if-changed spike` is clean | `tool/checks/T-0014-AC8_configs_parse.sh` | [`T-0014-AC8.md`](../evidence/T-0014/engineer/T-0014-AC8.md) |

**Deviations from plan 03:**
- Every Dart rule sets `language_version`.
- Route codegen gets the `sky_engine` dep.
- The extra package `spike/greeting` was added.
- `REPO.bazel` also ignores `app/**/build`, `spike/*/build` and `.fvm`.
- The analyze aspect is attached by `build --aspects` (once, for every command), and `test` / `--config=lint` only request its output groups (F-0009 gotcha 6).
- `--config=profile` writes `%workspace%/bazel-mc-*` instead of fixed `/tmp` names.
- The overlay is the minimal spike form (`pubspec.yaml`, lock, `spike_reference.sh`), not the full `run.sh` / `fallback.yaml` mechanism.

**Follow-ups (for `pending-work.md`):**
- `buildgen` / `mc_codegen` must emit `language_version`, and the `sky_engine` dep on codegen over Flutter.
- File an upstream issue for the embedder guard (F-0007).
- Plan 04 §7.2 says `--jobs` "auto" for arm T, while the 03 §1.4 block sets `--jobs=14`; reconcile.
- Check why the release iOS engine is fetched for a debug simulator build (F-0009).
- P4: kernel variant duplication between tests and the debug app (F-0010).
- P4: measure the analysis memory of the always-attached analyze aspect at S2 (F-0009).
- T-0005 `tool/verify.sh` must run `build --config=lint //...`: `test` checks only the test target's own files (F-0009 gotcha 7).

## Merge (TL)
- 2026-11-23: Verifier PASS `e7563e8` (plus a lint finding). `/code-review` found 4 important issues plus nits, all fixed in `d29ee32` along with ID-named checks under `tool/checks/`. Re-verify PASS `c2dbcee`. The TL merged `--no-ff` and re-ran `T-0014-AC5` and `T-0014-AC8` on the merge result: both PASS.
- Follow-ups: P-023 to P-027. The F-0007 upstream bug goes into the P3-13 upstream drafts.
