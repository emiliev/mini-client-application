# T-0032: `characters_list` exemplar feature (LD), P1-17 feature package

| Field | Value |
|---|---|
| Status | In Progress (branched from T-0031 head `8c0264c`; merges `origin/main` after T-0031) |
| Owner | crew: Engineer (**Opus**, worktree). This is the template the generators will copy, so quality outweighs speed |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0032-characters-list` |
| Created | 2026-11-25 |
| Depends on | T-0022 (`mc_feature_flow`, `mc_bloc_kit`), T-0023 (`mc_api_client`), T-0025 (l10n), T-0026 (`mc_test_utils`), T-0027 to T-0029 (retrofit, injectable, BDD in Bazel), T-0030 (`mc_paging`, `mc_media`), T-0031 (DS lists, media, cards) |
| Related | [plan 01 §3.3, §4, P1-17](../plan/01-architecture-and-modules.md), [plan 05 §3](../plan/05-testing-and-bdd.md), ADR-0007, ADR-0010, R4, R6, R15 to R17, R30, F-0018, F-0025, F-0027, F-0028, P-053 |

## Goal
The first real Marvel feature, built exactly to the Lego architecture: `feature/characters/characters_list`. It is a paged grid of characters, with an in-flow preview that leads out to the character's full profile. It uses every part of the stack:
- `FeatureFlow` with its own DI scope (injectable, via the T-0028 shim)
- an `McBloc` with a freezed sealed state (R16, R30)
- a retrofit API (T-0027) over `mc_api_client` and the mocked backend
- `mc_paging` with `McPagedGrid` and `McMediaCard`
- per-package gen-l10n in en and de
- BDD `.feature` files compiled by the T-0029 generator

Phase D's generators (mason bricks, buildgen) will copy this package, so its shape has to be the one we want a hundred times.

## Scope
- **In:**
  - **`mc_api_client`:** add the `ApiResponse<T>` / `ApiPage<T>` envelope, using `spike/api_envelope` as the template (P-053). It must match the `pageEnvelope` the mocked backend returns.
  - **`feature/characters/characters_list`:** the layout and code shapes of plan 01 §3.3, verbatim where the plan gives code.
    - **Barrel:** exports only `CharactersListFlow`, `CharactersListNavigator` and the flow arg/result types (R4).
    - **Navigator:** `CharactersListNavigator` with `openCharacter(CharacterId id)` only. `openComic` and `requestSignIn` wait for the features that need them; record that as a follow-up.
    - **Flow state:** `CharactersListFlowState` (freezed) with `teamId?` and `previewId?`.
    - **Pages:** a list page plus a preview page. The preview is flow state, not a route (plan 01 §4.1), and has a "See full profile" button.
    - **Bloc:** `CharactersListBloc` built on `PagingController`. It loads the first page, loads more, refreshes, and retries.
    - **Data:** `CharactersListApi` (`@RestApi`, injectable `@factoryMethod`), `CharacterDto`, then a mapper to the domain `Character` with `id`, `name` and `ApiImage`, then the `CharactersListRepository`.
    - **DI:** `CharactersListDIInitializer` in Tide's verbatim shape. The flow's root imports are **hand-written for now**, with the resolve test R17 requires. `mcgen wire` generates them in Phase D; note it in the code and in a follow-up.
    - **l10n:** ARBs in en and de: title, preview button, empty and error copy.
    - **BDD:** `test/feature/characters_list.feature` and `characters_list_paging.feature`, with `@T-0032-ACn` tags and hand-owned steps in `test/feature/step/`. Reuse `mc_test_steps` where a step is generic, and add generic steps there if needed (P5-02 starts here).
    - **Contract test:** the DTO against the fixture JSON.
    - **Goldens:** the list (loaded, error, empty) and the preview, through `mc_test_utils`.
    - **Tests:** no solitary `test/unit/` (R6); the feature tests are sociable through the flow.
  - **`mc_fixtures_characters`:** add any fixture set the ACs need, such as `characters.paged_45` or a set with a `server_error` scenario, without changing the existing sets.
- **Out:**
  - `universe_wiring` routes and navigator impl, `universe_sandbox`, the simulator screenshot (EX-AC5) and the `CharacterDetailsRoute` wiring test (EX-AC3, second half). All of these are T-0033.
  - Team filtering UI, search, favourites and analytics.

## Acceptance criteria
- **T-0032-AC1 (EX-AC1):** Given the fixture set `characters.default`, when I open the list, then I see the first 30 characters in name order, each as an `McMediaCard` with its name and bundled art. BDD scenario.
- **T-0032-AC2 (EX-AC2):** Given a `server_error` on `GET /v1/characters`, then an error with Retry shows. When I tap Retry and the backend recovers, then the list shows. Given a failure on page 2, then the loaded items stay and the footer shows Retry. BDD scenarios.
- **T-0032-AC3 (EX-AC3, feature half):** When I tap a character, then its preview opens inside the flow and the flow state has `previewId`. When I tap "See full profile", then `CharactersListNavigator.openCharacter(id)` is called exactly once with that ID. When I go back from the preview, then the list keeps its scroll position and items. BDD, with a mock navigator.
- **T-0032-AC4 (EX-AC4):** Given locale `de`, then the title and the preview button come from the German ARB. Given `en_XA`, then the pseudo-locale renders without overflow. l10n test; also make sure `tool/l10n_check` covers the package.
- **T-0032-AC5 (EX-AC6):** When I scroll to the end of page 1, then page 2 is requested once (offset 30) and the list has 60 items. At the last page, no further request is made. BDD, with real drags.
- **T-0032-AC6, architecture and codegen:**
  - `mc_arch_check` passes, and the barrel exports only flow, navigator and arg/result types.
  - Every generated file comes from Bazel actions, and none is committed: retrofit `.g.dart`, injectable `.config.dart`, freezed, json, gen-l10n and the BDD test main.
  - For the API, DI config and DTO, the outputs are byte-identical to build_runner's. Use `tool/build_runner_overlay/spike_reference.sh` and `injectable_reference.sh`, generalising them as P-054 and P-059 describe.
  - A body edit in the bloc doesn't re-run the injectable aggregate or the retrofit part. Show this with an execution-log check.
- **T-0032-AC7, gates:**
  - Package coverage is ≥ 90 % (ADR-0010).
  - `test //...`, `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check` and `dart format` are all green.
  - Every AC has a test or scenario whose name, or tag-generated name, carries `T-0032-ACn`.

## Notes for the Engineer
- Read first, in order:
  1. `CLAUDE.md`, STATUS, the latest journal, `fleet/protocol.md`
  2. plan 01 §3.3, §4.1 and §4.2
  3. plan 05 §3
  4. ADR-0007 and ADR-0010
  5. R4, R6, R15 to R17 and R30 in the plan README
  6. findings F-0018, F-0024, F-0025, F-0027, F-0028, F-0029 and F-0030
  7. the T-0027, T-0028 and T-0029 task files, which show how to use each codegen macro
  8. `spike/retrofit_api`, `spike/di_sample` and the T-0029 BDD sample
- Use `@Freezed(fromJson: true, toJson: true)` on any freezed model with JSON (R30).
- **Bazel:** always `tool/bazelw --output_base=/tmp/mc-ob-T-0032-engineer`.
- **Commits:** commit WIP often, since usage limits stop agents mid-task.
- **Before handoff:**
  - Rebase onto `origin/main` (P-036).
  - Re-resolve the locks; never hand-merge them.
  - Make sure evidence scripts FAIL when they can't prove the claim.
- **Findings:** start at F-0031.
- **If a codegen shim can't handle a real-world case:** stop and write a finding. Don't work around it silently. That is exactly the data the stress test exists to find.

## Log
- 2026-11-25: Created and dispatched (TL) to an Opus engineer, on top of T-0031.
- 2026-11-25 (Engineer): Branched from `8c0264c`; merged `origin/main` twice (`e57ddb3`, T-0031 merged; `101aa7c`, T-0033 added). Both merges were docs-only, with no lock change to re-resolve.
- 2026-11-25 (Engineer): Every generator built on the first try. **No codegen shim failed on a real-world case**, so no R28 fallback was needed.
  - A freezed library behaviour surfaced: the deep `copyWith` refers to `$PagedStateCopyWith`, which `mc_paging`'s `show` barrel hides. build_runner emits the same bytes, so it is not the shim. The bloc state uses `@Freezed(copyWith: false)` (F-0031 A2).
  - Three run-time gotchas in plan 01's canonical code, fixed in the feature and marked in the code (F-0031 B): `context.di` inside `BlocProvider.create` asserts; a relative retrofit path loses `/v1`; `McTestApp` lacked Flutter's localisations.
- 2026-11-25 (Engineer): Handed off. Gates green; evidence in `documents/evidence/T-0032/engineer/`.

## Outcome
**Handed off** for verification on `fleet/T-0032-characters-list`. Finding: [F-0031](../findings/F-0031-first-feature-through-the-stack.md) (A: codegen, B: run-time gotchas). Evidence: [`documents/evidence/T-0032/engineer/`](../evidence/T-0032/engineer/).

### What was built
- **`feature/characters/characters_list`** in plan 01 §3.3's layout.
  - **Barrel:** `CharactersListFlow`, `CharactersListNavigator` and `CharacterId`, the navigator's argument (R4).
  - **Navigator:** `openCharacter(CharacterId)` only.
  - **Flow:** `CharactersListFlowState(teamId?, previewId?)` (freezed). The preview is a flow page named `preview` whose argument is `previewId`.
  - **Pages:** list and preview.
  - **Blocs:**
    - `CharactersListBloc`, over `PagingController`: load, load more, refresh, retry and preview. Its state is a sealed freezed union read with `state.when`, R16.
    - `CharacterPreviewBloc`: `@factoryParam CharacterId`; the only caller of the navigator.
  - **Data:**
    - `CharactersListApi` (`@RestApi`, injectable `@factoryMethod`) returning `ApiPage<CharacterDto>`;
    - `CharacterDto` + `ThumbnailDto` with `@Freezed(fromJson: true, toJson: true)` (R30);
    - mappers to the domain `Character(id, name, ApiImage)`;
    - `CharactersListRepository`, a lazy singleton per flow that remembers loaded characters for the preview.
  - **DI:** `CharactersListDIInitializer` (Tide's verbatim shape). The flow's root imports `[Dio, Monitoring]` are hand-written in `di/flow_scope.dart`, marked for `mcgen wire`, and pinned by `flow_scope_test`.
  - **l10n:** ARBs in en, de and `en_XA`, through `flutter_gen_l10n`.
- **`mc_api_client`:** `ApiPage<T>` (json_serializable, `genericArgumentFactories`, a Bazel action) matching the backend's `pageEnvelope`, `count` included.
  - **No `ApiResponse<T>`:** the contract has no `{code, data}` wrapper, so it would match no response (F-0031 B6). **TL decision needed.**
- **`mc_fixtures_characters`:** `CharacterUniverse.synthetic(n)`, `SyntheticCharactersDomain`, and `charactersFixtureSets` (`characters.default`, `characters.paged_45`, `characters.empty`). Facts are in CONTRACT.md. The existing domain, scenarios and snapshots are unchanged.
- **`mc_test_steps` (generic, P5-02 starts here):**
  - `the backend fails {route} with {kind}`, `the backend recovers`, `the backend received {request}`, `the backend received {n} requests for {route}`;
  - `the device locale is {tag}`, `the pseudo-locale is active` (file `the_pseudolocale_is_active.dart`; the generator drops hyphens, F-0031 A3);
  - `I swipe back`, `I pull to refresh`, `nothing overflows`;
  - plus `backendFailureNamed`.

### AC → test / scenario map
JUnit names: [test_names.txt](../evidence/T-0032/engineer/test_names.txt).

| AC | Tests (generated names carry the ID) |
|---|---|
| AC1 | `:bdd_test` "The first page lists 30 characters in name order [T-0032-AC1]": walks the grid with real drags; checks 30 `McMediaCard`s in the fixture's name order, each `Image` the bundled asset of its own thumbnail, and request `offset=0&limit=30`. Also `:golden_test` "T-0032-AC1 golden: the first page loaded"; `//utility/mc_api_client:api_page_test` and `//utility/mc_fixtures_characters:fixture_sets_test` (T-0032-AC1 cases) |
| AC2 | `:bdd_test` Scenario Outline "A failed first page explains the problem and retries" × server_error, timeout, offline, malformed (error copy from `mc_l10n_core`; `the backend recovers`, Retry, list shows) and "A failed second page keeps the loaded characters and offers Retry" (30 kept, footer copy + Retry, recover, Retry → 60). `:golden_test` "T-0032-AC2 golden: the first page failed" |
| AC3 | `:bdd_test`: "Tapping a character opens its preview inside the flow" (title, art, page `preview` on the flow's navigator, not the root one, with `previewId` as argument); "The full profile hands over to the app exactly once" (mocktail `verify(...).called(1)` + `verifyNoMoreInteractions`); "Going back from the preview keeps the list where I left it" (iOS edge swipe; exact scroll offset, 30 items, 1 request). `:golden_test` "T-0032-AC3 golden: the preview" |
| AC4 | `:bdd_test` "In German the title and the preview button come from the German strings" and "The pseudo-locale renders the list and the preview without overflow" (both `@l10n`). `//tool/l10n_check:workspace_gate_test` "T-0032-AC4 the gate checks the characters_list ARB set"; `l10n_check: OK` over the repo. `//utility/mc_test_utils:init_flow_test` "T-0032-AC4 initFlow in de has Flutter's German strings" |
| AC5 | `:bdd_test` "Scrolling to the end of the first page loads the second once" (real drags; 1 request at `offset=30&limit=30`, 2 in all, 60 items) and "At the last page no further page is requested" (`characters.paged_45`; 45 items, 2 requests, still 2 after another scroll to the end). `fixture_sets_test` (T-0032-AC5 cases) |
| AC6 | `:architecture_test` (the barrel is exactly the 3 types, all with `show`; every `:_stage` file is Flutter-free); `run //tool/mc_arch_check:bin` OK; `:flow_scope_test` (R17: `debugResolveAll` over the flow; a root without `Monitoring` fails naming `RootImport<Monitoring>`); `:contract_test` (DTO against the CONTRACT.md example and the served JSON, canonical round trip, mapper); `tool/checks/T-0032-AC6_matches_build_runner.sh`, `T-0032-AC6_cutoff.sh` and `T-0032-AC6_generated_not_committed.sh` (below) |
| AC7 | the gates below; coverage below |

Two scenarios carry no AC tag because no AC asks for them: "An empty catalogue says so" and "Pulling down reloads the first page". They cover the empty copy and refresh.

### Byte identity and cutoff (AC6)
- [T-0032-AC6_byte_identity.md](../evidence/T-0032/engineer/T-0032-AC6_byte_identity.md): **11 of 11 EQUAL**. That is retrofit `characters_list_api.g.dart` (sha256 `36401c9e…`), DTO `.freezed.dart` and `.g.dart`, domain, flow-state and bloc-state `.freezed.dart`, `di_initializer.config.dart` (`19268573…`) and all 4 injectable shards.
  - Both overlays get only the Flutter-free inputs (`MC_REF_SRCS_FROM=//…:_stage`) plus the init file.
  - Negative control: a bare `@freezed` on the DTO → DIFFER, FAIL.
- [T-0032-AC6_cutoff.md](../evidence/T-0032/engineer/T-0032-AC6_cutoff.md): a statement added to the bloc's `close()`. The bloc's freezed action and shard re-ran (positive controls). The aggregate made no spawn (an action-cache hit). No retrofit part, API combine or DTO json spawn. `.config.dart` and the API `.g.dart` are byte-identical. The bloc file is not an input of either action.
  - Negative control: retrofit wired to `:_stage` → the retrofit part re-runs, FAIL.
- [T-0032-AC6_generated_not_committed.md](../evidence/T-0032/engineer/T-0032-AC6_generated_not_committed.md): no generated file in the index. Every kind (retrofit, json, freezed ×4, injectable config and shard, gen-l10n, both BDD tests and their main) is a declared Bazel output and git-ignored.
  - Negative control: a staged fake `.g.dart` → FAIL.
- Generalised scripts (P-054, P-059, F-0031 A5):
  - `spike_reference.sh` compares only declared outputs, both ways; takes `MC_BAZEL_STARTUP` and `MC_REF_SRCS_FROM`; adds the package's hosted deps.
  - `injectable_reference.sh` follows first-party deps transitively.
  - Shared helpers: `overlay_deps.py`, `add_dep.py`.
  - The re-runs still PASS: T-0027-AC1 (5/5, same sha256), T-0028-AC1 and T-0014-AC7.

### Gates and coverage (AC7)
- `test //...`: **75/75** ([gate-test.log](../evidence/T-0032/engineer/gate-test.log)).
- `build --config=lint //...`: clean.
- `run //tool/mc_arch_check:bin`: OK; with a page exported from the barrel it fails R4 ([log](../evidence/T-0032/engineer/arch_negative_control.log)).
- `tool/rules_fork.sh check`: 3 patches apply strictly.
- `dart format --set-exit-if-changed` over `feature utility tool/l10n_check tool/mc_arch_check spike app`: 0 changed.
- `tool/l10n_check`: OK.
- **Coverage: 160/161 = 99.4 %** of hand-written `lib/` ([coverage.txt](../evidence/T-0032/engineer/coverage.txt)). Measured as the union of `bazel coverage //feature/...`; generated freezed, `.g.dart`, `.config.dart` and gen-l10n files are excluded. The one missed line is the `StateError` for a character the flow never loaded, which no flow path can reach.
- Mutations: [12 of 12 killed](../evidence/T-0032/engineer/mutations.log) by failing scenarios, none by a compile error ([script](../evidence/T-0032/engineer/mutations.sh)). The other negative controls are in [negative_controls.md](../evidence/T-0032/engineer/negative_controls.md).
- Goldens (402×874, real Inter and fixture art): [loaded](../evidence/T-0032/engineer/goldens/characters_list_loaded.png), [error](../evidence/T-0032/engineer/goldens/characters_list_error.png), [empty](../evidence/T-0032/engineer/goldens/characters_list_empty.png), [preview](../evidence/T-0032/engineer/goldens/character_preview.png).

### Root and shared changes
- **Root:**
  - `pubspec.yaml`: workspace member `feature/characters/characters_list`;
  - `pubspec.lock`: re-resolved with `fvm flutter pub get`; **added** flutter_bloc 9.1.1, provider 6.1.5+1, nested 1.0.0 and mocktail 1.0.5 (ADR-0007's stack); nothing moved;
  - `MODULE.bazel.lock`: regenerated by Bazel;
  - `.gitignore`: `*.config.dart`, `*.injectable.json`, `**/test/feature/*_test.dart` (plan 01 §3.1).
- **Outside the named packages (TL, please confirm):**
  - **`mc_test_utils`:** `McTestApp` installs `GlobalMaterialLocalizations.delegates` (+ the `flutter_localizations` dep and a test). AC4's German scenario cannot pass without it: `MaterialApp` reports the unsupported locale itself (F-0031 B3).
  - **`tool/checks/lib.sh`:** `bzw`, and `T-0014-AC7` / `T-0027-AC1` now use it, so they read the same output base as the reference script under `MC_BAZEL_STARTUP`. Assertions unchanged.
  - **`tool/l10n_check`:** the gate's data plus one test (AC4 asks for it).

### Test integrity
No test deleted, skipped or weakened. No `// ignore:` added. Goldens are new (4), and no existing golden changed. The two older checks changed only how they invoke Bazel.

### Decisions for the TL
1. **`mc_feature_flow`:** make `context.di` non-listening, so plan 01's `BlocProvider(create: (c) => c.di<X>())` works. Also add `provide:` and `localizationsDelegates:`. The feature has marked workarounds (F-0031 B1, B4).
2. **`mc_paging`:** export `$PagedStateCopyWith`, or keep `@Freezed(copyWith: false)` for bloc states in the templates (F-0031 A2).
3. **Base URL:** end `AppConfig.apiBaseUrl` with `/`, or make templates use leading-slash paths (as here; F-0031 B2).
4. **`ApiResponse<T>`:** omitted (F-0031 B6). Is a response wrapper wanted in the contract?
5. **Mocks:** mocktail is now in the lock; F-0024's hand-written `MockMonitoring` could move to it (P5).

### Follow-ups (for `pending-work.md`)
- `mcgen wire` generates `di/flow_scope.dart`; `mcgen check` replaces the hand-written list.
- The navigator gains `openComic` and `requestSignIn` when comics_details and auth exist.
- buildgen: per-API-file json/retrofit lanes; a Flutter-free `:_stage`; per-file freezed lanes, since every pure edit re-runs all 4 freezed actions and all shards (F-0031 A4, P-057).
- `mc_arch_check`: the exact barrel rule the feature's `architecture_test` enforces (R4 today only forbids names).
- Plan 01 §3.3 code: the `McFailureState` field names (`error`, `stackTrace`), `McFlowPage`, the `/v1` path, and the `BlocProvider` lookup.
- Plan 05 §3.2 catalogue: generated step names (hyphens dropped).
- `mc_test_steps`: solitary tests for the new generic steps (today only the feature's BDD runs them).
- `the backend recovers` resets the engine but leaves the harness's mirrored fail rules, so unmatched detection stays off for that route.
- UX: a failed pull-to-refresh with items shows the "Could not load more characters." footer.
- The app shell (T-0033) needs `McMediaScope` and Flutter's localisation delegates at its root.
