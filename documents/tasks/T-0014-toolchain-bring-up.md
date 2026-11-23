# T-0014: Toolchain bring-up under Bazel (P3-01, spike S1)

| Field | Value |
|---|---|
| Status | In Progress |
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
- 2026-11-23 (Engineer): Fixed the crash with the `@flutter_sky_engine//:sky_engine` dep on route codegen (F-0007). Set `language_version = "3.13"` so the shims format like build_runner (F-0008). Pinned `analyzer` and `source_helper` in the overlay (F-0008). Moved `greeting` into its own package `spike/greeting`, because a same-package library has no outline (F-0009). Ran every AC; findings F-0006 to F-0010.

## Outcome
**Done: all 8 ACs pass on Bazel 9.3.0 / Flutter 3.47.7 (Dart 3.13.5).** V3-01 is settled: go_router_builder stays Bazel-native, but every codegen action over a Flutter closure needs the `sky_engine` dep until rules_dart or rules_flutter fixes the embedder guard (F-0007). R16 holds: freezed emits `when`/`maybeWhen`/`map`.

| AC | Result | Evidence |
|---|---|---|
| T-0014-AC1 | PASS. `tool/bazelw build --config=sim //spike/hello:hello_ios` builds `hello_ios.ipa` (23.7 s warm; 893 s cold, mostly fetch). The app launches on `mc-T-0014-engineer` (iPhone 17 Pro, iOS 26.2), which was then deleted | [`ac1-build-sim.log`](../evidence/T-0014/engineer/ac1-build-sim.log), [`ac1-launch.md`](../evidence/T-0014/engineer/ac1-launch.md), [`ac1-launch-sim.png`](../evidence/T-0014/engineer/ac1-launch-sim.png), [`ac1-launch.sh`](../evidence/T-0014/engineer/ac1-launch.sh) |
| T-0014-AC2 | PASS. `tool/bazelw test //spike/hello:widget_test` passes 3 cases with DartAnalyze and DartFormat on (the first run failed the format check, then the sources were formatted). Test `T-0014-AC2 hello app renders and counts under Bazel` | [`ac2-widget-test.log`](../evidence/T-0014/engineer/ac2-widget-test.log) |
| T-0014-AC3 | PASS. Bundled Dart 3.13.5. `greeting.flutter.koutline` and `greeting.koutline` are byte-identical after a body-only edit, while `.kmod` changed. 0 stripper-fallback lines | [`ac3-h-sdk.md`](../evidence/T-0014/engineer/ac3-h-sdk.md), [`ac3-h-sdk.sh`](../evidence/T-0014/engineer/ac3-h-sdk.sh) |
| T-0014-AC4 | PASS (measured). DartCodegen duplicated 3/3 across configurations. DartKernel: 1 exact duplicate, plus 12/32 targets compiled as two variants | [`ac4-h-cfgdup.md`](../evidence/T-0014/engineer/ac4-h-cfgdup.md), [`cfgdup.py`](../evidence/T-0014/engineer/cfgdup.py), F-0010 |
| T-0014-AC5 | PASS. `fvm flutter --version` in the repo reports Flutter 3.47.7 | [`ac8-configs-parse.md`](../evidence/T-0014/engineer/ac8-configs-parse.md) §AC5 |
| T-0014-AC6 | PASS. `.freezed.dart` has `when`/`maybeWhen`/`map` (plus `maybeMap`, `whenOrNull`, `mapOrNull`) on a private-case sealed union; `state.when` compiles in the app and test, and it is byte-identical to build_runner's. Test `T-0014-AC6 …` | [`ac6-ac7-codegen.md`](../evidence/T-0014/engineer/ac6-ac7-codegen.md) |
| T-0014-AC7 | PASS after the F-0007 workaround. `routes.g.dart` compiles and is byte-identical to build_runner's (`tool/build_runner_overlay/spike_reference.sh spike/hello`). Test `T-0014-AC7 …` navigates via `$appRoutes`. The stock first-run crash is recorded | [`ac6-ac7-codegen.md`](../evidence/T-0014/engineer/ac6-ac7-codegen.md), [`ac7-first-cold-build-crash.log`](../evidence/T-0014/engineer/ac7-first-cold-build-crash.log), [`ac7-summaries-per-action.txt`](../evidence/T-0014/engineer/ac7-summaries-per-action.txt) |
| T-0014-AC8 | PASS. `lint`, `ci`+`cold`, `budget16`, `tool/bazelw --budget16`, `budget16_8c`, `profile`, `remote-cache`, `sim`, `device-profile` and `app` all parse; a negative control with an undefined config fails | [`ac8-configs-parse.md`](../evidence/T-0014/engineer/ac8-configs-parse.md) |

**Deviations from plan 03:**
- Every Dart rule sets `language_version`.
- Route codegen gets the `sky_engine` dep.
- The extra package `spike/greeting` was added.
- `REPO.bazel` also ignores `**/build` and `.fvm`.
- The overlay is the minimal spike form (`pubspec.yaml`, lock, `spike_reference.sh`), not the full `run.sh` / `fallback.yaml` mechanism.

**Follow-ups (for `pending-work.md`):**
- `buildgen` / `mc_codegen` must emit `language_version`, and the `sky_engine` dep on codegen over Flutter.
- File an upstream issue for the embedder guard (F-0007).
- Plan 04 §7.2 says `--jobs` "auto" for arm T, while the 03 §1.4 block sets `--jobs=14`; reconcile.
- Check why the release iOS engine is fetched for a debug simulator build (F-0009).
- P4: kernel variant duplication between tests and the debug app (F-0010).
