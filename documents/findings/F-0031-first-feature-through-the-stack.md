# F-0031: The first feature through the whole stack: codegen under Bazel (A) and run-time gotchas in plan 01's code (B)

- **Date:** 2026-11-25
- **Author:** crew: Engineer (T-0032)
- **Type:** Spike / library behaviour / bug root cause
- **Related:** T-0032, F-0018, F-0024, F-0025, F-0026, F-0027, F-0028, P-054, P-059, plan 01 §3.3 and §4.5, plan 03 §3.4 and §4.7, R15, R16, R17, R30, ADR-0007

## Part A: codegen

### Summary
`characters_list` is the first package that uses every generator at once: freezed, json_serializable, retrofit, injectable, gen-l10n and BDD. **No shim failed on a real-world case**, so the R28 build_runner fallback is not needed. With the Flutter-free inputs (`:_stage`) copied into the overlays, all 11 freezed, json, retrofit and injectable outputs are byte-identical to stock build_runner's. One library behaviour bites every feature that keeps a `PagedState` in its bloc state: freezed's deep `copyWith` refers to `$PagedStateCopyWith`, which `mc_paging`'s `show` barrel hides, so the library does not compile. build_runner emits the same bytes, so the shim is not at fault.

### Facts
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

### Evidence
- `tool/checks/T-0032-AC6_matches_build_runner.sh` → [T-0032-AC6_byte_identity.md](../evidence/T-0032/engineer/T-0032-AC6_byte_identity.md): 11 of 11 EQUAL. Negative control: a bare `@freezed` on `CharacterDto` → `character_dto.freezed.dart` DIFFER, FAIL ([report](../evidence/T-0032/engineer/T-0032-AC6_byte_identity_negative_control.md)).
- `tool/checks/T-0032-AC6_cutoff.sh` → [T-0032-AC6_cutoff.md](../evidence/T-0032/engineer/T-0032-AC6_cutoff.md) and [negative control](../evidence/T-0032/engineer/T-0032-AC6_cutoff_negative_control.md).

### Implications / actions
- Templates and buildgen: emit `@Freezed(copyWith: false)` for bloc states (or export `$XCopyWith` from kit barrels: TL); per-API-file json/retrofit lanes; a `:_stage` of Flutter-free files only (the feature's `architecture_test` checks that list).
- The shared step catalogue (plan 05 §3.2) should spell generated names, or the scaffold should print them.
- No shim needed a patch; no upstream item.

## Part B: run-time gotchas in plan 01's canonical code

### Summary
Plan 01 §3.3's code for the exemplar feature compiles in most places but fails at run time in three, and two kit APIs differ from what it assumes. Phase D's generators copy this package, so each item below is either fixed in the feature (and marked in the code) or needs a TL decision on a shared package. None is a codegen problem.

### Facts
1. **`context.di<T>()` inside `BlocProvider.create` throws.** `McFlowContext.di` goes through `FlowScope.of`, which calls `dependOnInheritedWidgetOfExactType`. provider (under flutter_bloc 9.1.1) locks dependencies while a lazy `create` runs and asserts: "Tried to listen to an InheritedWidget in a life-cycle that will never be called again". On unmount the provider then fails again (`type 'Null' is not a subtype of type 'CharactersListBloc'`). Plan 01's `create: (context) => context.di<CharactersListBloc>()` therefore fails on every page.
   - **In the feature:** the page reads `FlowScope.of(context).container` in `build` (a legal dependency) and `create` calls that container.
   - **Proper fix (TL, `mc_feature_flow`):** `di` and `debugResolveAll` use `getInheritedWidgetOfExactType<FlowScope>()` (no dependency; the flow's container never changes while the scope lives). The plan's one-liner then works as written.
2. **A relative retrofit path drops the API version.** Dio joins `baseUrl + path` as strings, and `AppConfig.apiBaseUrl` is `https://mock.mini-client.invalid` (no trailing slash). So `@GET('v1/characters')` requests host `mock.mini-client.invalidv1`, path `/characters`. The harness caught it as `Unmatched request GET /characters`. The feature uses `@GET('/v1/characters')`. Either templates use a leading `/`, or `apiBaseUrl` ends with `/` (TL: config is app-wide).
3. **`McTestApp` had no Flutter localisations.** With `locale: de`, `MaterialApp` reports "This application's locale, de, is not supported by all of its localization delegates" (Material and Cupertino) and the test fails on that report. The flow's own `Localizations.override` cannot help, because the report comes from `MaterialApp` itself. `McTestApp` now installs `GlobalMaterialLocalizations.delegates` (`mc_test_utils`, plus `flutter_localizations`; test `T-0032-AC4 initFlow in de has Flutter's German strings`). The production app shell needs the same when it gains l10n.
4. **`FeatureFlow` has no `provide:` and no `localizationsDelegates:`** (plan 01 §3.3 and §4.5 list both; T-0022 built neither).
   - The flow registers the navigator inside its `flowInitializer` (`McDIInitializer` that registers it, then runs `CharactersListDIInitializer`).
   - The flow wraps itself in `Localizations.override` with its delegates plus `mcLocalizationsDelegates`.
   - Both are marked in `characters_list_flow.dart`. Adding the two parameters to `FeatureFlow` would let the template match the plan.
5. **`McFailureState` needs fields named `error` and `stackTrace`.** Plan 01's `@Implements<McFailureState>() failure(ApiFailure failure)` does not compile against `mc_bloc_kit`. The state is `failure(ApiFailure error, {StackTrace? stackTrace})`.
6. **The mocked backend has no response wrapper.** `GET /v1/characters` returns the page envelope itself (`offset`, `limit`, `total`, `count`, `results`), so `mc_api_client` gains `ApiPage<T>` only. An `ApiResponse<T>` (`code`, `status`, `data`, the T-0027 spike's model of Tide's `MarvelResponse`) would match no response; the API returns `ApiPage<CharacterDto>`. If the contract should wrap responses, that is a contract change in `mc_fixtures_characters` (TL / PO).
7. **Hosts must provide `McMediaScope` and an asset bundle.** `McImage` throws without a `McMediaScope` (T-0031). Feature tests wrap the flow in `McMediaScope(resolver: BundledImageResolver())` plus `DefaultAssetBundle(McFixtureAssetBundle())` (`charactersTestHost`). The app root does the same in T-0033.
8. **flutter_bloc and mocktail were not in the lock.** Both are in ADR-0007's stack. Root `pubspec.lock` now has flutter_bloc 9.1.1 (with provider 6.1.5+1 and nested 1.0.0) and mocktail 1.0.5; nothing else moved. F-0024 item 1's hand-written `MockMonitoring` stays; navigator mocks are mocktail `Mock`s.

### Evidence
- 1: the first BDD run (all 15 scenarios failed with the provider assertion); the stack shows `FlowScope.of` ← `McFlowContext.di` ← `CharactersListPage.build.<closure>` ← `_CreateInheritedProviderState.value`.
- 2: the second run: every scenario failed with `Unmatched request GET /characters`.
- 3: the third run: only the German scenario failed, on the delegates warning.

### Implications / actions
- TL decisions: `mc_feature_flow` (`di` without a dependency, `provide:`, `localizationsDelegates:`); `apiBaseUrl` trailing slash or leading-slash paths; `ApiResponse<T>` or not; `mc_paging` exporting `$PagedStateCopyWith` (Part A, fact 2).
- Until those land, buildgen and the mason bricks copy the feature's workarounds, which are marked in the code with this finding's number.
