# F-0013: mc_analysis lint facts and test-runtime gotchas (T-0017)

Found while building `mc_analysis`, `mc_arch_check`, `mc_di` (2026-11-23, Dart 3.13.5, Bazel 9.3.0).

1. **Two of Tide's 22 rules are dead on Dart 3.13.5.** `unnecessary_await_in_return` is deprecated (a `deprecated_lint` warning appears on the file that enables it). `package_prefixed_library_names` reports nothing for `library wrong.name;` in a package `lib/` (checked with a hand-built package and package config). Both are left out of `mc_analysis`.
2. **`dart analyze` and the Bazel `dart_analyze` aspect disagreed once.** A parenthesised cast in a test file (`unnecessary_parenthesis`) was flagged by `fvm dart analyze` but passed `bazel build --config=lint`. Cause not found. Run both until it is. (Unverified whether the cause is the aspect's summary analysis or the pinned analyzer.)
3. **Lint rules are only exercised if the root options file has the ruleset in `deps`.** `dart_analysis_options(src = "analysis_options.yaml")` with an `include: package:mc_analysis/...` and no `deps` appeared to pass (not isolated): an unresolvable include seems to apply no rules, with no error. `//:options` now has `deps = ["//utility/mc_analysis"]`.
4. **Format runs as part of `bazel test` and fails the target.** Run `fvm dart format` before Bazel. Duplicate keys in `analysis_options.yaml` crash the format worker (`Duplicate mapping key`), not the analyzer.
5. **Runfiles are symlink trees.** A test that walks fixture directories must use `listSync(followLinks: true)` and `FileSystemEntity.isFileSync`; `entity is File` is false for a symlinked file. `dart_test` runs with the cwd at the runfiles root, and the test can shell out to `Platform.resolvedExecutable analyze` (the Bazel toolchain SDK), which `lints_test` does.
6. `dart test` in a package also collects `*_test.dart` files inside `test/fixtures/`, so fixture files must not end in `_test.dart`.
