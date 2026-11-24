# F-0026: retrofit_generator under Bazel, spike facts (shim, ext lock, rerun scope)

- **Date:** 2026-11-24
- **Author:** crew: Engineer (T-0027)
- **Type:** Spike
- **Related:** T-0027, plan 03 §4.3 (S2), KD7, X9, R28, F-0011, F-0025, [U-D-retrofit](../upstream/U-D-retrofit/README.md)

## Summary
retrofit_generator 10.3.3 runs as a Bazel action through a plain SharedPart shim (rules patch 0001), and its `.g.dart` is byte-identical to build_runner's on the first attempt. **R28 is not needed for retrofit.** What it took, and what to know:

1. **Builder factory (S2 settled):** `retrofitBuilder` in `package:retrofit_generator/retrofit_generator.dart`. It is a `SharedPartBuilder` with part id `retrofit`, so the shard suffix is `.retrofit.g.part` and the stock `combining_shim` merges it. No shim changes were needed.
2. **Ext lock:** retrofit_generator 10.3.3 accepts analyzer `>=8.4.1 <15.0.0` and build `>=4.0.2 <6.0.0`. `pub get` in `dart/ext` (not `upgrade`) adds only retrofit_generator 10.3.3, retrofit 4.10.0, dio 5.11.1 and dio_web_adapter 2.2.2 and moves nothing else. It needs Flutter's `pub` (`~/fvm/versions/3.47.7/bin/flutter pub get`), because go_router_builder declares a Flutter constraint. rules_dart's hub merges the dio cycle into an SCC target (`ext_pub_deps__scc__dio__dio_web_adapter`). That is harmless here: it's the generator's own closure, and our `@pub_deps` keeps its F-0019 `cycle_breaks`.
3. **Overlay pins:** json_serializable 6.14.1 plus a plain resolve picks source_helper 1.4.0, which fails to compile (`constructorByName`, `toStringNonNullable` and `qualifiedName` defined twice). That is the same clash F-0011 hit with go_router_builder. `source_helper: 1.3.13` (as in the ext lock) is required in the overlay and in the upstream repro.
4. **Wiring:** the retrofit action's deps are the per-file `_stage_frz` (the model and its `.freezed.dart`) plus `dio`, `retrofit` and the envelope package. The envelope from another package arrives as an analyzer summary (15 `--summary` args, no `sky_engine`). `ApiResponse<ApiPage<CharacterDto>>` (nested `genericArgumentFactories`) is generated exactly as build_runner generates it.
5. **Rerun scope (AC2):** with per-file staging, a body edit in the API file reruns **11 spawns**: the retrofit part and combine (each twice, because the `dart_test` transition builds a second configuration; this is X9 / H-CFGDUP), the library's analyzer summary (×2), kernel, analyze and format, and the test's link and run. Nothing in the model's or the envelope's codegen reruns. The retrofit shard is byte-identical after the edit, but combine still reruns because it reads the source.
6. **Measurement gotcha:** don't change `--disk_cache` between the "before" and "after" builds of a rerun measurement. When the first build had the disk cache on and the second had it off, 311 spawns "ran" (everything, the SDK summary included) even though only one file changed. With identical flags on both builds, the count is 11.
7. **Gazelle** doesn't know `@RestApi`, and patch 0001 doesn't add it (no Go toolchain here to run `//gazelle/...`). We don't use Gazelle (KD5, buildgen), so this is only an upstream follow-up.

## Evidence
- [T-0027-AC1](../evidence/T-0027/engineer/T-0027-AC1.md): 5 files `EQUAL`; `characters_api.g.dart` sha256 `36eebd91…d0ea`.
- [T-0027-AC2](../evidence/T-0027/engineer/T-0027-AC2.md): the spawn list from the execution log.
- [T-0027-AC3](../evidence/T-0027/engineer/T-0027-AC3.md): the ext lock as Bazel patched it, plus the gates.
- [AC4 repro run](../evidence/T-0027/engineer/T-0027-AC4-repro.log): through the `retrofit_library` macro, 3 files `EQUAL`. [Fork tests](../evidence/T-0027/engineer/fork-tests.log): 631 of 633 pass. The 2 that fail to build (`dart/tests/defines_fixture`, `compile_wrapper`) fail with dartvm exit 247 in `DartKernel` and have no `dart/ext` dependency.

## Implications / actions
- `mc_codegen` (P3-06): `retrofit = [...]` maps to `dart_codegen(generator_bin = "@rules_dart//dart/ext/retrofit:shim", output_suffixes = [".retrofit.g.part"], deps = [_stage_frz, dio, retrofit, <envelope>])` and a combine. Use per-file staging for API files, or a package-wide `_stage` reruns the model codegen on every API edit.
- The injectable-on-API question in plan 03 §4.3 (does `@injectable` + `@factoryMethod` on `= _CharactersApi` resolve without the `.g.dart`?) is left to T-0028.
