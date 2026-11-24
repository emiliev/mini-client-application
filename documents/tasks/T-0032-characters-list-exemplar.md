# T-0032: `characters_list` exemplar feature (LD), P1-17 feature package

| Field | Value |
|---|---|
| Status | Ready (dispatch after T-0030 and T-0031 merge) |
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
- 2026-11-25: Created (TL).
