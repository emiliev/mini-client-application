# F-0026: injectable under the rules_dart shim: `Resolver.libraries` order decides the output; the overlay needs its own lock

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0028)
- **Type:** Bug root cause / spike result
- **Related:** T-0028 (AC1, AC2), plan 03 §4.2, KD7, X3, P3-04, R28, V3-04, F-0011; patch `third_party/rules_patches/ai_rules_dart/0002-ext-injectable-two-stage.patch`; [evidence](../evidence/T-0028/engineer/)

## Summary
1. **The rules_dart shim's `Resolver.libraries` is not build_runner's, and injectable depends on it.** The shim yields the staged same-package files and then each package's `lib/<name>.dart` (`builder_shim.dart:1495`). build_runner 2.16 yields the SDK libraries, then a breadth-first walk from the input over imports, then exports (`build_step_resolver.dart:31-73`). injectable_generator records the *first* library that exports a type as its `import` and the others as `otherImports`, and `otherImports` feed `ImportableType.hashCode`, which feeds `DependencyConfig.identityHash`, which is the first sort key for registrations (`builder_utils.dart:97-99`). So with the stock shim the output was **not** byte-identical in two realistic cases:
   - the package barrel (`lib/di_sample.dart`) staged in the shard deps: every in-package import became `package:di_sample/di_sample.dart` instead of `package:di_sample/src/<file>.dart`;
   - a class with a third-party constructor parameter (`Dio`): the shard lost `otherImports: [package:dio/src/dio.dart]`, the hash changed, and `.config.dart` registered `Badge` in a different position.
   **Fix (patch 0002, the R28 fix round):** both injectable shims hand the generator a `BuildStep` whose resolver's `libraries` reimplements build_runner's walk (`BuildRunnerLibrariesResolver` in `dart/ext/injectable/lib/injectable_shims.dart`). Result: `.config.dart` and all five non-empty shards are byte-identical in both cases. One known gap: build_runner yields *every* public SDK library first; the wrapper yields only those the walk reaches. That matters only for an element exported by two SDK libraries.
2. **Other shim generators that read `Resolver.libraries` can have the same drift.** The shim's comment cites stacked_generator. The general fix belongs in `builder_shim.dart` (upstream issue in the U-D-injectable draft); we kept it local to injectable so patch 0002 can't change any other generator's output.
3. **The build_runner reference for injectable can't live in the shared overlay.** Stock injectable_generator 3.1.3 needs lean_builder 1.2.2 (`_fe_analyzer_shared >=98 <106`), so pub resolves analyzer **14.1.0**, while `tool/build_runner_overlay/pubspec.yaml` pins 14.5.0 for freezed/go_router (F-0011). It has its own pubspec and lock in `tool/build_runner_overlay/injectable/`, with build_runner **2.16.1** (2.16.2 does not resolve with it) and dart_style 3.1.14, source_gen 4.3.1, build 4.0.11, code_builder 4.13.0 pinned to the ext lock. The analyzer difference (14.1.0 vs 14.5.0) did not show up in any output.
4. **The `[]` shard is not build_runner's behaviour, but equivalent.** build_runner writes no shard for a library with no injectable class; Bazel must write the declared output, so `shim_json` writes `[]`. The comparison script reports it as `EMPTY ... (expected)`.
5. **Every shard re-runs on any edit.** The shard actions take `_stage` (all hand-written files) as deps, so a body edit in one file re-executes all six shard actions (they are cheap and come out byte-identical). The aggregate is still an action-cache hit, which is what H-DI-CUTOFF needs. Narrower shard deps (per-file import closure) would cut this; that is buildgen's job.
6. **An unresolved `@InjectableInit` fails inside source_gen already** ("Could not resolve annotation"), before the wrapper's check. The wrapper's own error fires when the file has no `@InjectableInit` at all. Both cases fail the build and write nothing (AC4).

## Evidence
- AC1: `tool/checks/T-0028-AC1_injectable_matches_build_runner.sh` → [ac1.md](../evidence/T-0028/engineer/ac1.md) (`EQUAL` for `.config.dart` and 5 shards).
- Before the fix (the two failing cases above), from `tool/build_runner_overlay/injectable_reference.sh spike/di_sample`:
  ```
  -import 'package:di_sample/src/badge.dart' as _i146;      (build_runner)
  +import 'package:di_sample/di_sample.dart' as _i100;      (shim, barrel staged)

  DIFFER  spike/di_sample/lib/src/di/di_initializer.config.dart   (Badge(…, gh<_i361.Dio>()) registered one position later)
  -..."otherImports":["package:dio/src/dio.dart"]...         (build_runner shard)
  ```
- AC2: [ac2.md](../evidence/T-0028/engineer/ac2.md), [ac2-execlog.json](../evidence/T-0028/engineer/ac2-execlog.json): six `DartCodegen` spawns, no `DartAggregateCodegen` spawn, shard and config sha256 unchanged.

## Implications / actions
- `mc_codegen` / buildgen (P3-06, P2 C4): use `injectable_package` from `@rules_dart//dart/ext/injectable:defs.bzl`; `init_deps` only what the init file imports; the package barrel may be in `_stage` (the wrapper makes it harmless).
- Upstream: rules_dart issue "shim `Resolver.libraries` differs from build_runner's" (in `documents/upstream/U-D-injectable/`).
- The R28 fallback is **not** needed for injectable.
- When the ext lock or the overlay pins move, re-run the AC1 check; keep the injectable overlay's generator-side pins equal to the ext lock.
