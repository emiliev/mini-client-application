# F-0041: `tool/ide_sync`: what the generated code in the checkout can and cannot do

- **Date:** 2026-11-26
- **Author:** crew: Engineer (T-0042)
- **Type:** Gotcha / design record
- **Related:** T-0042, plan 03 KD11 and §7.1, R10, R13, R28, F-0021, F-0023, F-0032, F-0033

## Summary
`tool/ide_sync` copies Bazel's generated Dart next to the sources so that the analyzer, `fvm flutter run`, the debugger and hot reload work on the checkout. Six things were learned the hard way.

1. **A synced file in a `glob(["lib/**/*.dart"])` breaks the build.** rules_dart fails analysis with "`srcs` contains two files that resolve to the same package-relative path" (the source copy and the `bazel-out` one). Every package with codegen must exclude the synced files, in `srcs` and in `data` globs (an architecture test that reads `lib/**` would otherwise scan generated code). The shared constant is `MC_GENERATED_DART` in `tool/bazel/defs.bzl`. A package without codegen needs nothing, but `tool/checks/T-0042-AC4_safety.sh` proves it: it asks `bazel query 'kind("source file", deps(//...))'` whether any synced file is a source of any target, and compares the hash of every output of `build //...` with and without a sync (they are equal, and the synced tree runs no action and no test).
2. **Do not sync gen-l10n.** `fvm flutter pub get` and `flutter run` regenerate `lib/src/l10n/*_l10n*.dart` themselves (`generate: true`, `l10n.yaml`) and format it differently from Bazel's output. A synced copy was rewritten by every `pub get` and recopied by every sync (6 files, every time). `ide_sync` leaves l10n to Flutter; the BUILD globs still exclude it.
3. **`flutter run` needs more than the Xcode project.** `flutter create --platforms=ios` also adds `Runner/Runner-Bridging-Header.h` (the project references it; the Bazel-only runner dir lacks it) and the launch image. `ide_sync` runs `flutter create` in a scratch copy and copies in every file the checkout lacks, never an existing one, and refuses if one of them is not git-ignored. The first Xcode build of a checkout takes minutes; later runs about 20 s.
4. **The app's asset list is pub-only.** `assets: - assets/app_config.json` in the two apps' `pubspec.yaml` is read only by the Flutter tool; Bazel bundles its own genrule output with the same name. A source file with the name of a genrule output is harmless as long as no glob picks it up.
5. **List the outputs with `query`, then `cquery` the labels.** `cquery //...` analyses `manual` targets too, and `//spike/hello:hello_ios` fails analysis on a fastbuild. `ide_sync` runs `bazel query` for the codegen rule kinds (`dart_codegen`, `dart_aggregate_codegen`, without `manual`), builds those labels, and `cquery --output=files` over exactly them. The BDD generators (`dart_sqlcodegen`, `bdd_suite_main`) write only into `bazel-out` and are not synced.
6. **Nothing synced can be committed.** `ide_sync` refuses, before writing anything, a destination that is tracked or not git-ignored, skips the paths of the R28 fallback manifest (`tool/build_runner_overlay/fallback.yaml`, does not exist yet; every list item that looks like a path counts), and never deletes a tracked file when cleaning stale entries.

## Numbers (M4 Pro, warm disk cache)
- 23 synced files (the app's own and the spikes'); full first sync 5.5 s, fresh output base 10 s, no-op sync 1.5 to 1.9 s, an edited freezed model 9.3 s the first time and 1.6 s from the disk cache, `--watch` 2.5 to 3.0 s from save to synced file (1 s polling).
- The analyzer on a fresh clone: 176 errors and 11 warnings before, 0 and 0 after.
- With the synced tree, `build //...` and `test //...` run no action and no test, and all 27,610 files under `bazel-bin` hash the same as without a sync.

Evidence: `documents/evidence/T-0042/engineer/`.
