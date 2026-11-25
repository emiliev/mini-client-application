# F-0031: The first feature's codegen under Bazel: what the shims handled, and freezed's deep copyWith across a `show` barrel

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0032)
- **Type:** Spike / library behaviour
- **Related:** T-0032-AC6, F-0025, F-0026, F-0027, F-0028, P-054, P-059, plan 03 §3.4 and §4.7, R15, R16, R30

## Summary
`characters_list` is the first package that uses every generator at once: freezed, json_serializable, retrofit, injectable, gen-l10n and BDD. **No shim failed on a real-world case**, so the R28 build_runner fallback is not needed. With the Flutter-free inputs (`:_stage`) copied into the overlays, all 11 freezed, json, retrofit and injectable outputs are byte-identical to stock build_runner's. One library behaviour bites every feature that keeps a `PagedState` in its bloc state: freezed's deep `copyWith` refers to `$PagedStateCopyWith`, which `mc_paging`'s `show` barrel hides, so the library does not compile. build_runner emits the same bytes, so the shim is not at fault.

## Facts
1. **Handled with no change to any shim:**
   - nested freezed + JSON across two classes in one file (`CharacterDto` with a `ThumbnailDto` field and `@JsonSerializable(explicitToJson: true)`), with the json action reading the freezed output through a per-file stage (`_stage_dto`). This answers plan 03 §3.4's open question S2: it works;
   - a freezed union whose case holds a generic type from another package (`success(PagedState<Character> page)`), with `@Implements<McFailureState>()`;
   - a bloc library with hand-written `part` files (event, state) as a freezed input: the parts reach the shim as same-package siblings of `:_stage`;
   - an extension type (`CharacterId`) as a freezed field and as an injectable `@factoryParam`: `gh.factoryParam<CharacterPreviewBloc, CharacterId, dynamic>`;
   - a generic constructor parameter (`FeatureFlowController<CharactersListFlowState>`) resolved by injectable;
   - `@injectable` + `@factoryMethod factory X(Dio dio) = _X;` on a retrofit API whose `_X` lives in the not-yet-generated `.g.dart`. Injectable reads the factory's parameters; the shard equals build_runner's. This answers the question F-0026 left open;
   - `@Freezed(copyWith: false)` on a sealed union.
2. **freezed's deep copyWith ignores import visibility.** For a field whose type is a freezed class, freezed emits `$<Type>CopyWith<…>` in the union's copyWith. `mc_paging`'s barrel exports `show PagedState` only, so the generated code does not compile (`Type '$PagedStateCopyWith' not found`). Stock build_runner emits the same bytes, with three references to `$PagedStateCopyWith` ([log](../evidence/T-0032/engineer/F-0031-copywith-reference.log), bloc state EQUAL with the bare `@freezed`). The feature uses `@Freezed(copyWith: false)`: the bloc emits whole states and never copies one. The alternative is for `mc_paging`'s barrel to also export `$PagedStateCopyWith`, which is a TL decision because `mc_paging` was not T-0032's to edit.
3. **BDD step names drop hyphens.** `the pseudo-locale is active` becomes `thePseudolocaleIsActive` in `the_pseudolocale_is_active.dart` (bdd_widget_test's naming). The generator says so at build time ("1 step(s) have no definition … -> the_pseudolocale_is_active.dart"). The plan 05 catalogue spells the text with a hyphen, so the shared step file carries the hyphen-less name.
4. **Staging lanes decide the cutoff.** With one package-wide `:_stage` for every generator, a bloc body edit re-runs the retrofit part as well (negative control: retrofit wired to `:_stage` makes `T-0032-AC6_cutoff.sh` FAIL, with 4 bloc files among its inputs). The feature therefore uses `:_stage` for freezed and the injectable shards, and a DTO-only `:_stage_dto` for json and retrofit. A bloc body edit then re-runs the 4 freezed actions and the 4 shards (outputs byte-identical), plus the library summary. It does not run the aggregate (an action-cache hit) or the retrofit, API combine or DTO json actions ([evidence](../evidence/T-0032/engineer/T-0032-AC6_cutoff.md)). Plan 03 §3.4's example gives retrofit `deps [_stage_frz]` with package staging, which would re-run retrofit on every bloc edit. buildgen should emit the narrow lane per API file (F-0026 said the same for per-file staging).
5. **Reference scripts, generalised (P-054, P-059).**
   - `spike_reference.sh` compares only declared outputs, in both directions. It takes `MC_BAZEL_STARTUP`, adds the package's hosted deps to the overlay, and with `MC_REF_SRCS_FROM=<library>` copies only that library's sources (a Flutter feature's Flutter-free inputs).
   - `injectable_reference.sh` follows pure-Dart first-party deps transitively (it was hard-coded to `mc_di`). It allows packages that only the package's own deps add, still pins every package of its committed lock, and takes the same `MC_REF_SRCS_FROM` plus the aggregate's init file.
   - Shared helpers: `overlay_deps.py` and `add_dep.py`.
6. **The older checks read the default output base.** `T-0014-AC7` and `T-0027-AC1` called `tool/bazelw info` / `aquery` without `MC_BAZEL_STARTUP`, while the reference script they wrap now honours it, so with an explicit output base they read the wrong `bazel-bin` and failed. `tool/checks/lib.sh` now has `bzw` (bazelw plus `MC_BAZEL_STARTUP`), and both checks use it. Both PASS again with identical hashes.

## Evidence
- `tool/checks/T-0032-AC6_matches_build_runner.sh` → [T-0032-AC6_byte_identity.md](../evidence/T-0032/engineer/T-0032-AC6_byte_identity.md): 11 of 11 EQUAL. Negative control: a bare `@freezed` on `CharacterDto` → `character_dto.freezed.dart` DIFFER, FAIL ([report](../evidence/T-0032/engineer/T-0032-AC6_byte_identity_negative_control.md)).
- `tool/checks/T-0032-AC6_cutoff.sh` → [T-0032-AC6_cutoff.md](../evidence/T-0032/engineer/T-0032-AC6_cutoff.md) and [negative control](../evidence/T-0032/engineer/T-0032-AC6_cutoff_negative_control.md).

## Implications / actions
- Templates and buildgen: emit `@Freezed(copyWith: false)` for bloc states (or export `$XCopyWith` from kit barrels: TL); per-API-file json/retrofit lanes; a `:_stage` of Flutter-free files only (the feature's `architecture_test` checks that list).
- The shared step catalogue (plan 05 §3.2) should spell generated names, or the scaffold should print them.
- No shim needed a patch; no upstream item.
