# F-0007: rules_dart passes analyzer summaries to codegen over a Flutter closure, and the shim crashes

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0014)
- **Type:** Bug root cause / spike result (V3-01)
- **Related:** T-0014-AC7, plan 03 KD6 and §4.5, §4.7 (U-D5), R28, [evidence](../evidence/T-0014/engineer/ac6-ac7-codegen.md)

## Summary
Plan 03 KD6 assumes that rules_dart turns analyzer summaries **off** for any codegen action whose closure contains Flutter (`dart_codegen.bzl:124-133`). **With rules_flutter's `@pub_deps//:flutter` it doesn't.** The guard `embedder_in_closure` looks for a `sky_engine` package (or `lib/_embedder.yaml`) in the deps' `DartInfo`. rules_flutter's `flutter_library` adds `sky_engine` only to its analysis provider (`DartAnalyzableInfo`, `flutter/private/flutter_library.bzl:575-609`), never to `DartInfo`. So the go_router shim gets `--summary …/flutter.dart_analyzer_summary.sum`, a summary of `package:flutter` built without `dart:ui`. The analyzer then crashes:

```
Unhandled exception:
Null check operator used on a null value
#0 LibraryReader._readDirectiveUri.readWithSource (package:analyzer/src/summary2/bundle_reader.dart:418:52)
…
DartCodegen @@//spike/hello:routes_go_router_part failed: Worker process did not return a WorkResponse
```

It is deterministic and happens on the first build. Every codegen action whose deps include any Flutter library is affected, not only go_router.

## Workaround (used in `spike/hello/BUILD.bazel`)
Add `@flutter_sky_engine//:sky_engine` to that `dart_codegen`'s `deps`, and `use_repo(flutter, "flutter_sky_engine")` in `MODULE.bazel`. The guard then fires, summaries are off for that action only (0 `--summary` args, checked with `aquery`), and the shim analyzes `dart:ui` from source through `_embedder.yaml`. With that, go_router_builder 4.5.0 over **real go_router 17.5.0** produces a `.g.dart` byte-identical to build_runner's (once F-0008 is also applied). V3-01 is therefore **settled: go_router_builder stays Bazel-native and does not join the R28 fallback.**

Alternative: `--@rules_dart//dart:analyzer_summaries=false` also works, but it turns summaries off for every codegen action, including the roughly 95 % that are Flutter-free under CPR. Rejected.

## Implications / actions
- `mcgen buildgen` (P2) and the `mc_codegen` macro (P3-06) must add the `sky_engine` dep to every codegen action whose deps reach Flutter (route files), or our fork must fix the guard. Pending work for the TL.
- **Upstream fix (new candidate, rules_dart or rules_flutter):** either `flutter_library` records `sky_engine` in `DartInfo.transitive_packages` (or a marker the guard can read), or `embedder_in_closure` also checks `DartAnalyzableInfo`. Fits under U-D5 (embedder summaries for codegen); a minimal repro is `spike/hello` with the `sky_engine` dep removed.
- Summaries stay off for route codegen, which is the cost plan 03 §4.7 already budgeted.
