# T-0014-AC6 / AC7: stock freezed and go_router shims vs build_runner

**Reference outputs:** `tool/build_runner_overlay/spike_reference.sh spike/hello`. It copies `spike/hello/lib` into the git-ignored `.dart_tool/mc_overlay/hello/`, runs build_runner 2.16.2 with freezed 4.0.2 and go_router_builder 4.5.0 (analyzer 14.5.0 and source_helper 1.3.13, matching rules_dart's ext lock @ e7163aa), and `cmp`s each output with `bazel-bin/spike/hello/`. Nothing is copied back or committed (R10 / D7).

```
EQUAL   spike/hello/lib/src/counter_state.freezed.dart
EQUAL   spike/hello/lib/src/routes.g.dart
```

| File | sha256 (Bazel = build_runner) |
|---|---|
| `counter_state.freezed.dart` | `cab0d955b3da934aeda9d2b473e9b11c12ed653c0d6d664eb82fede5da627489` |
| `routes.g.dart` | `9c1849aadf14574b59b09322689fae17fb4d5fcefe55f2d1bb7d43f01402bb29` |

## AC6: freezed `when` (R16)
- `lib/src/counter_state.dart` is a `sealed` union with **private** cases (`_Initial`, `_Counting`, `_Failed`), Tide's shape.
- The stock shim's `.freezed.dart` declares `extension CounterStatePatterns` with `maybeMap` (line 59), `map` (83), `mapOrNull` (103), `maybeWhen` (126), `when` (149) and `whenOrNull` (168).
- `pages.dart` calls `_state.when(...)` and `_state.maybeWhen(...)`, and `counter_state.dart` calls `state.map(...)`. They compile in `hello_lib`, `widget_test` and the iOS app. The test case `T-0014-AC6 state.when / maybeWhen / map on a private-case union` passes.
- **R16 holds: no `switch` fallback is needed.**

## AC7: go_router_builder over real go_router 17.5.0 in a Flutter closure (V3-01)
- **First attempt: the shim crashed** ([log](ac7-first-cold-build-crash.log)): `Null check operator used on a null value` in `LibraryReader._readDirectiveUri` (analyzer `summary2/bundle_reader.dart:418`), so the worker returned no WorkResponse. It is deterministic (it reproduced on a re-run).
  - **Root cause:** rules_dart passed analyzer summaries to this action (`--summary …/flutter.dart_analyzer_summary.sum`). That summary was built without `dart:ui`. rules_dart's `embedder_in_closure` looks for `sky_engine` in `DartInfo`, but rules_flutter's `flutter_library` adds `sky_engine` only to its analysis provider (`DartAnalyzableInfo`, `flutter_library.bzl:575-609`), so the guard never fires. See F-0007.
- **Workaround (in `spike/hello/BUILD.bazel`):** list `@flutter_sky_engine//:sky_engine` in the route codegen's `deps` (and `use_repo` it in `MODULE.bazel`). Summaries then switch off for that action only ([`ac7-summaries-per-action.txt`](ac7-summaries-per-action.txt): `routes_go_router_part` 0 `--summary` args; `counter_state_freezed`, which is Flutter-free, keeps 4). The global `--@rules_dart//dart:analyzer_summaries=false` also works, but it costs every codegen action.
- **Byte equality needed one more fix:** without `language_version`, the shims run with `--root-language-version 3.0`, so dart_style formats in the pre-3.7 "short" style and both files differ from build_runner's (whitespace only). With `language_version = "3.13"` (the pubspec floor) on every Dart rule, both files are byte-identical. See F-0008.
- `.g.dart` compiles in `hello_lib`, the test and the app. `T-0014-AC7 generated $appRoutes navigates to the typed DetailRoute` passes.
- **Outcome:** go_router_builder stays **Bazel-native**; it does not join the R28 fallback. It needs a patch, or the documented `sky_engine` dep, until the upstream guard is fixed.
