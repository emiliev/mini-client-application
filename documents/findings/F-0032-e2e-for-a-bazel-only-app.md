# F-0032: Running a Bazel-only app under `tool/e2e_ios.sh` (`flutter drive`)

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0033)
- **Type:** Tooling gap / workaround
- **Related:** T-0033-AC3, AC4, T-0012, F-0004, F-0020, R10, R13, ADR-0006

## Summary
`tool/e2e_ios.sh` runs `fvm flutter drive` in pub mode. The apps can't do that as they stand: generated code is never committed (R10), the config asset only exists as a Bazel genrule (R13), and the apps carry only the Bazel runner files (`ios/Runner/*.swift`, `Info.plist`), with no Xcode project. T-0021 got its screenshots by installing the Bazel build with `simctl` and could not tap anything. T-0033-AC4 needs taps (Characters, a character, "See full profile"), so it needs an in-app `integration_test`.

## What was done
`tool/e2e/prepare_pub_project.sh --app <dir> --out <scratch>` asks `cquery` which targets under the app library's deps make a generated Dart file (`.g.dart`, `.freezed.dart`, `.config.dart`, gen-l10n) and builds exactly those with `--remote_download_outputs=all`, so a fresh output base works. It copies the repo's own files (git's tracked-plus-untracked-not-ignored list, so no stale generated file, `bazel-*` link or `documents/`), copies the listed outputs from the execroot to their source paths, bundles `tool/bazel/config/e2e.json` as `assets/app_config.json`, runs `flutter create --platforms=ios --no-pub .` (it keeps existing files) and `flutter pub get`. The working tree is not touched. `tool/e2e_ios.sh --project <scratch>/<app>` then runs unchanged.

`mini_client` has **18** generated files (the sandbox 17). An earlier version of this finding said 212: that was a `find` over `bazel-bin`, which also picked up exec-configuration copies, runfiles and symlink trees, and, from a fresh output base with a warm disk cache, missed outputs that were never materialised. `tool/checks/T-0033-e2e_prepare.sh` proves the fix: it wipes the output base, plants a git-ignored stale `.g.dart` in the tree, runs the script, and checks that the copy holds exactly the built outputs and not the planted file, with two negative controls (a stale and a junk file in the copy make the same verify step fail). [Report](../evidence/T-0033/engineer/T-0033-e2e_prepare.md).

The test files and drivers live in the apps (`integration_test/`, `test_driver/integration_test.dart`). The driver exits 2 when `SCREENSHOT_DIR` is unset, so a run can't pass without producing evidence. The tests call the real `main()`, so the production boot, router, wiring, backend and bundled art are what is driven.

## Facts
1. **`flutter drive` on iOS needs `integration_test` as a dev dependency** of each app. That added 7 entries to `pubspec.lock` (SDK `integration_test`, `flutter_driver`, `fuchsia_remote_debug_protocol`; hosted `platform`, `process`, `sync_http`, `webdriver`); nothing moved.
2. **One journey per target file.** `main()` calls `runApp` and `initializeDIContainer`, which publishes once per process (R17: production never resets). A second `main()` in the same process throws, so each journey is its own `integration_test/*_test.dart` and its own `flutter drive` (fresh app).
3. **`pumpAndSettle` hangs** on the loading spinner, so the tests poll with `tester.pump(100 ms)` until a finder matches (`pumpUntil`), with a timeout that fails the test.
4. **The first screenshot after the names appear shows grey art.** The cards render before their images decode. The tests wait 3 s of real time (`letArtLoad`) before the list screenshot; the grey frame is in the history of this task (the first run's `02_characters_list.png`).
5. **The first `flutter drive` of a fresh scratch directory takes about 6 minutes** (Xcode build, pods); later runs on it take 20 to 35 s per target.
6. **The deep link uses the file-drop hook** (F-0020): the test writes `<tmp>/mc_e2e_link` before `main()`, which reads and deletes it.
7. **The app's error hooks make a failing e2e hang.** `main()` calls `installErrorHooks()`, which replaces `FlutterError.onError`. When an `expect` then fails, the binding asserts ("A test overrode FlutterError.onError but either failed to return it...") and `flutter drive` never returns (a negative control sat for over 30 minutes). `startApp` in `integration_test/e2e_support.dart` saves both handlers, runs `main()` and puts them back, so a wrong expectation exits 1 in 36 s.
8. **A `RouteTargets` member must return a `*Flow`** (`mc_arch_check` R15). The first draft returned `Widget`, and the guard failed with exactly that message.

## Evidence
`documents/evidence/T-0033/engineer/{mini_client,sandbox}/` (`e2e-summary.md`, logs, screenshots at most 1200 px). Negative control: a wrong expected string in the journey makes `tool/e2e_ios.sh` exit 1 ([summary](../evidence/T-0033/engineer/e2e-negative-control-summary.md), [log](../evidence/T-0033/engineer/e2e-negative-control.log)).

## Implications
- P-042 (a real `simctl openurl` e2e) still stands; this does not touch it.
- A `tool/e2e` wrapper that prepares and runs in one go, and caches the scratch project, would cut the per-run cost. Not done: out of T-0033's scope.
