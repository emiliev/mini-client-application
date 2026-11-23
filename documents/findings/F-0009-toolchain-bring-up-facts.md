# F-0009: Toolchain bring-up facts (SDK fetch, H-SDK, outlines, caches)

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0014)
- **Type:** Spike
- **Related:** T-0014, plan 03 §1 and §8 (S1), R18, H-SDK, [evidence](../evidence/T-0014/engineer/)

## Summary
The pinned toolchain works end to end: Flutter 3.47.7 (bundled **Dart 3.13.5**), Bazel 9.3.0, ai_rules_dart `e7163aa`, ai_rules_flutter `876e263`, rules_apple 5.2.0 and Xcode 26.2. The iOS simulator app builds and launches, and the widget test passes with the analyze and format aspects on. H-SDK holds: outlines strip (kernel format 138) and no fallback diagnostic appears. The first fetch is large and slow.

## Evidence
| Item | Observation |
|---|---|
| `fvm install 3.47.7` | 55 s; FVM's global stays 3.47.8. `fvm flutter --version` in the repo reports 3.47.7 / Dart **3.13.5** (plan 03 expected 3.13.6) |
| Bazel's own Flutter SDK | fetched by rules_flutter (not FVM's); `dart-sdk/version` = 3.13.5 |
| Cold first build (`--config=sim //spike/hello:hello_ios`, empty caches) | **893 s wall**, almost all repository fetching over this network (critical path 28.6 s). Afterwards `~/.cache/mc-bazel/repo` = **3.4 GB** (861 MB downloads in `content_addressable/`, 2.6 GB extracted repo contents, the Bazel 9 contents cache), and the output base is 0.7 GB. bazelisk downloads add 195 MB |
| iOS engines | **both** `flutter_ios_engine_debug` and `flutter_ios_engine_release` were fetched for a `-c dbg` simulator build (each carries a ~140 MB `Flutter.framework.dSYM`). Research §3 said the hub fetches lazily; observed it didn't |
| Non-iOS repos fetched | `rules_go` `go_sdk`, `rules_kotlin` compiler and the `rules_android` SDK repository were materialised during the iOS build, as plan 03 §1.1 warned |
| Warm rebuild (`--config=sim`) after a BUILD change | 23.7 s |
| H-SDK, outline | a body-only edit in `spike/greeting` changed `greeting.flutter.kmod` and left `greeting.flutter.koutline` and `greeting.koutline` **byte-identical**; 0 `falling back to unstripped dill` lines in build output and in `bazel-workers/*.log` |
| `~` in `--disk_cache` / `--repository_cache` | expands to `$HOME` |
| rc-file trailing `# comments` | accepted; every config parses on 9.3.0 (AC8) |

## Gotchas
1. **A library in the same package as its consumer gets no outline of its own.** `hello_lib` (package `hello`), consumed by `widget_test` (also `hello`), produced *empty* `hello_lib.flutter.kmod/` and `.koutline/` directories, because its sources are compiled into the test's entry module. Early cutoff through `.koutline` therefore works only across package boundaries. That fits Tide's many small packages, but tests within a package always recompile it. The spike moved the AC3 subject into its own package, `spike/greeting`.
2. **With the disk cache on, intermediate outputs are not written to `bazel-out`.** In Bazel 9 a disk-cache hit is not downloaded unless the output is top-level ("build without the bytes"). Directories like `.koutline/` then exist but are empty. Pass `--remote_download_all` (or `--remote_download_outputs=all`) when an experiment inspects intermediate files. `tool/build_runner_overlay/spike_reference.sh` and the AC3 script rely on this.
3. **`fvm flutter pub get` at the workspace root writes iOS debris** into every member that has an `ios/` directory: `ios/Flutter/{Generated.xcconfig,flutter_export_environment.sh,ephemeral/}` and `ios/Runner/GeneratedPluginRegistrant.{h,m}`. These files are git-ignored; Bazel generates its own registrant.
4. A first-party workspace member (`spike/greeting`) adds **no** entry to `pubspec.lock`, which confirms P2 C7 / KD3.
5. The Bazel-built simulator app shows the debug banner, and `simctl` screenshots can catch system notifications (an "Apple Intelligence" banner covered the app bar on a fresh iOS 26.2 device). Wait or dismiss before taking visual checkpoints.
6. **Bazel refuses a duplicate aspect.** Plan 03 §1.4 sets the analyze aspect under both `test` and `build:lint`, so `test --config=lint` fails with `aspect … dart_analyze added more than once`. Also using `test --config=lint` inside the rc only adds "configs were expanded more than once". The fix: `build --aspects=…dart_analyze` once, for every command, while only the output groups (`dart_analyze`, `dart_format`) are switched on: always under `test`, and under `build --config=lint`. With its output groups unrequested, the aspect adds no actions; a sim build's analysis time and heap were unchanged here. P4 should re-measure the analysis memory at S2.
7. **`bazel test` checks only the test target's own files.** The aspect runs on the targets the command names, so `test //spike/hello:widget_test` formats and analyses `test/widget_test.dart`, not `hello_lib`. An unformatted `lib/src/pages.dart` passed AC2 and was caught only by `build --config=lint //spike/...`; the Verifier found it, because the engineer's lint log was stale. `T-0014-AC8` therefore runs the real lint build plus `fvm dart format --set-exit-if-changed spike`, and the future `tool/verify.sh` must lint `//...`, not just test it.
