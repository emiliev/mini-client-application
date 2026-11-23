# F-0011: Codegen output equals build_runner's only with `language_version` set; the overlay needs two pins

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0014)
- **Type:** Gotcha
- **Related:** T-0014-AC6/AC7, plan 03 §4 and §7.3, R28, P3-03/P3-04 (byte-equality ACs), P4-14

## Summary
1. **Set `language_version` on every Dart rule.** Without it, `dart_codegen` runs the shim with `--root-language-version 3.0`, so dart_style formats generated code in the pre-3.7 "short" style. build_runner uses the package's real language version (3.13, from `sdk: ^3.13.0`) and the "tall" style. freezed and go_router outputs then differ from build_runner's in whitespace only. With `language_version = "3.13"` on the codegen and library targets, both are **byte-identical** (sha256 in the [evidence](../evidence/T-0014/engineer/ac6-ac7-codegen.md)). `buildgen` must emit it from each pubspec.
2. **build_runner overlay pins.** A plain `freezed 4.0.2` + `go_router_builder 4.5.0` resolve picks `source_helper 1.4.0`, and go_router_builder then fails to compile (`The property 'qualifiedName' is defined in multiple extensions for 'ExecutableElement'`, `type_helpers.dart:832`). It also picks `analyzer 14.7.0`, while rules_dart's ext lock has 14.5.0. `tool/build_runner_overlay/pubspec.yaml` therefore pins `analyzer: 14.5.0` and `source_helper: 1.3.13`, both from the ext lock @ e7163aa. Other drifts that remain harmless: `build_config` 1.3.3 vs 1.4.0, `pubspec_parse`, `crypto`, `shelf`, `web`, `http_multi_server`.
3. **freezed output carries `// dart format off`**, so `dart format` won't normalise it for a comparison. Compare bytes, or strip the markers first.

## Implications
- P3-03/P3-04/P3-05 byte-equality ACs depend on (1). Copy the pins in (2) into any overlay extension, and recheck them when the ext lock moves.
- The overlay's scratch tree lives under the root `.dart_tool/` (git-ignored, and `REPO.bazel` ignores it), so it never enters `//...` or the root lock (R10).
