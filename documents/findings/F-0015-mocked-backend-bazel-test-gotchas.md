# F-0015: Pure-Dart utility packages under Bazel: tests, data files and fake_async

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0018)
- **Type:** Gotcha
- **Related:** T-0018, plan 01 §3 and §5, plan 05 (contract tests), F-0009, F-0012

## Summary
1. **Pure-Dart packages test with `flutter_test` for now.** `package:test` is not in the root `pubspec.lock` (only `test_api`), so `dart_test` has nothing to run on. `flutter_test` plus `@pub_deps//:flutter_test` works for plain `test()` / `group()` in a `dart_library` package (`flutter_test` as a dev dependency, `fake_async` as an extra dev dependency). Adding `test` would be a root lock change; decide in P3/P5 whether pure-Dart packages should get it.
2. **A `dart_library` can depend on a `flutter_library`.** `mc_fixtures_characters` (`dart_library`) depends on `mc_fixtures_media` (`flutter_library` with `assets`). Analysis and tests were fine.
3. **Test data files.** A `flutter_test` with `data = [...]` runs with `TEST_SRCDIR` set and `TEST_WORKSPACE=_main`; files are at `$TEST_SRCDIR/_main/<package path>/...`. The tests try that path first and fall back to the checkout-relative path (the fallback is unverified under plain `fvm flutter test`). Data from another package (`//utility/mc_fixtures_media:asset_files`) is listed in `data` too.
4. **Dio yields to the event loop once.** Under `fake_async`, `flushMicrotasks()` is not enough for a `dio.get` to complete even with no delay; `elapse(Duration.zero)` is. `async.elapsed == Duration.zero` and `pendingTimers.isEmpty` still prove no latency was added. The engine's own `handle()` completes on microtasks alone, and AC2 asserts that too.
5. **Plain Dart scripts in a workspace member run with `fvm dart run <path>` from the repo root** (used by `tool/update_snapshots.dart` and `tool/generate_placeholders.dart`), including scripts that import `package:` code from workspace members.
6. **VM `int` arithmetic is 64-bit wrapping**, so SplitMix64 in plain Dart `int` is exact on the VM. It would not be on Dart web; the mock is not used there.
7. The `test` rule's analyzer runs `prefer_const_constructors` (from the root `analysis_options.yaml`) on the test file: a constant `MockResponse.ok({...})` in a test closure fails the analyze aspect, which fails the test target.

## Implications
- `buildgen` (P3) must emit `deps = ["@pub_deps//:flutter_test"]` for pure-Dart packages until `test` is in the lock.
- Tests that read files should use the `TEST_SRCDIR` lookup above; a shared helper could live in `mc_test_utils` later.
