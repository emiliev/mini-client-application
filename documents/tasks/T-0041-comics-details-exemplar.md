# T-0041: `comics_details` exemplar (SC archetype), P1-18

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: first SC exemplar, which the bricks copy; ADR-0011) |
| Verifier | crew: Verifier, **Opus tier** (exemplar, auth-gated write) |
| Branch | `fleet/T-0041-comics-details` |
| Created | 2026-11-26 |
| Depends on | T-0032 to T-0037 (the LD exemplar and its kits), T-0038 (`mc_fixtures_comics`), T-0039 (`mc_session`, `mc_api_auth`, `mc_fixtures_identity`, `McTestContainer` auth), T-0040 (`mc_ds_navigation`) |
| Related | plan 01 F011, P1-18, §3.3 and §4; the SC archetype row; ADR-0007, ADR-0010, ADR-0011; R4, R6, R15 to R17, R30; F-0031, F-0033, F-0036, F-0038 |

## Goal
The second archetype exemplar, **section/detail (SC)**: `feature/comics/comics_details`. It's one comic's page, made of sections: a cover header, synopsis, facts (issue, price, pages, release date, formatted per locale), creators, characters, and a favourite toggle that requires sign-in. It also adds the app wiring, so the characters preview and the deep link `miniclient://app/comics/<id>` reach it.

Like `characters_list` (T-0032), this package is the shape the P1-24 bricks copy for every SC feature. Its code must match plan 01 §3.3's conventions and the T-0034 and T-0037 kit shapes, with no workarounds.

## Scope
- **In:**
  - **`feature/comics/comics_details`:**
    - `ComicsDetailsFlow`, with args `ComicId`
    - `ComicsDetailsNavigator`, with `openCharacter(CharacterId)`, `openCreator(CreatorId)` and `requestSignIn() → Future<bool>`
    - a retrofit API (`GET /v1/comics/{id}`, favourites `GET/PUT/DELETE /v1/me/favourites/comic/{id}`) through `mc_api_client` and `mc_api_auth`
    - a stateless repository and a freezed sealed state
    - pages built from `McAppBar(leading: const McFlowBackButton())`, `McSectionHeader`, `McImage` and `McMediaCard`, with `mc_formatters` for price and date
    - l10n in en and de
    - BDD `.feature` files, a contract test, goldens, and no solitary unit tests (R6)
  - **The favourite:**
    - Signed out: tapping favourite awaits `requestSignIn()`. On `true`, the favourite is saved and `DataChanged('favourites')` is published on `mc_event_bus`. On `false`, nothing changes.
    - Signed in: the toggle is optimistic, with a rollback and an inline error if the write fails.
  - **`app/wiring/publishing_wiring`:**
    - routes `/comics/:id` (`ComicDetailsRoute`)
    - the navigator implementation
    - `AppLocations.comic(id)` and the drift test
    - `openCharacter` pushes the characters placeholder route for now
  - **`requestSignIn` in the wiring:** a minimal sign-in sheet that signs in through `mc_session` with a fixture user. This stands in until a real sign-in feature exists (P-044). It must stay out of the feature package.
  - **`characters_list`:** the preview's "related comics" link, `openComic`, which was P-068.
  - **mini_client:** a deep link to a comic. Add `IdentityMockDomain` and the comics domain to `appMockDomains`.
- **Out:**
  - "add to list" (library)
  - variants carousel, credits and cast pages (other SC features)
  - the real sign-in feature and the auth redirect guard

## Acceptance criteria
- **T-0041-AC1 (EX-AC1):** Given `comics.default`, when I open comic 501500, then the cover, title, issue number, synopsis and the facts section show, with price and date formatted for en. The creators and characters sections list the fixture's credits. BDD.
- **T-0041-AC2 (EX-AC2):** Given a `server_error` on the detail endpoint, then an error with Retry shows, and Retry recovers. Given an unknown id, then a not-found state shows (not a crash). BDD.
- **T-0041-AC3 (EX-AC3):** When I tap a character in the cast section, then `openCharacter(id)` is called exactly once. In the app, the wiring test pushes the characters placeholder location. BDD with a mock navigator, plus a wiring test.
- **T-0041-AC4 (EX-AC4):** Given locale `de`, then the section titles, the favourite labels, and the price and date formats are German. Given `en_XA`, then nothing overflows.
- **T-0041-AC5 (EX-AC5):** The `publishing` route opens the page on the simulator. Covered by the mini_client e2e: home → Characters → preview → related comic → comic page, and the deep link `miniclient://app/comics/501500`. Screenshots.
- **T-0041-AC6 (P1-18 AC6):**
  - Given signed out, when I tap favourite, then `requestSignIn()` is awaited. On `true` the favourite is saved (backend traffic shows the PUT with a bearer) and `DataChanged('favourites')` is published exactly once. On `false`, no request is made.
  - Given signed in, a failed write rolls the toggle back and shows an inline error.
  - A double tap sends one request.
  - BDD, with real `mc_api_auth` and the identity fixtures through `McTestContainer`.
- **T-0041-AC7 (architecture and codegen):**
  - `mc_arch_check` passes, and the barrel exports only the flow, the navigator and the arg/result types.
  - No generated file is committed, and the retrofit, injectable, freezed, json and l10n outputs are byte-identical to build_runner's.
  - A bloc body edit doesn't re-run the injectable aggregate or the retrofit part.
  - The fixtures check passes.
- **T-0041-AC8 (gates):** Package coverage is ≥ 90 %. `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and `l10n_check` all pass. Every AC is traceable by a `T-0041-ACn` name.

## Notes for the Engineer
- Read first:
  1. CLAUDE.md, STATUS, the latest journal, `fleet/protocol.md` (including Model tiers and the review-first flow), ADR-0011.
  2. The T-0032 task file and `feature/characters/characters_list`. It's your reference; match its shapes.
  3. T-0034, T-0036, T-0037, T-0038, T-0039 and T-0040, and their findings.
  4. plan 01 §3.3 and §4.
- Use `@Freezed(fromJson: true, toJson: true)` for JSON models (R30). API paths are relative (`'v1/comics/{id}'`).
- Bazel: always use `tool/bazelw --output_base=/tmp/mc-ob-T-0041-engineer`. Use your own scratch folder and simulators, and always delete the simulators.
- If a codegen shim fails on a real-world case, stop and write a finding.
- Findings start at F-0040.

## Log
- 2026-11-26: Created (TL); dispatched after T-0039 and T-0040 merged. The engineer may also lift the P-080 auth pins if they touch the auth tests.
- 2026-11-26 (Engineer): Branched from `origin/main` `4c70671` (unchanged at handoff, so no merge). Every generator built on the first try: **no codegen shim failed on a real-world case**, so no R28 fallback. One kit gap (date symbols, F-0040 fact 1) has a marked workaround and needs a TL decision. Handed off; evidence in `documents/evidence/T-0041/engineer/`.

## Outcome
**Handed off** for review and verification on `fleet/T-0041-comics-details`. Finding: [F-0040](../findings/F-0040-section-detail-exemplar.md). Evidence: [`documents/evidence/T-0041/engineer/`](../evidence/T-0041/engineer/).

### What was built
- **`feature/comics/comics_details`** (SC), in plan 01 §3.3's layout and characters_list's shapes:
  - **Barrel:** `ComicsDetailsFlow`, `ComicsDetailsNavigator`, and the argument types `ComicId`, `CharacterId`, `CreatorId` (extension types; R4).
  - **Navigator:** `openCharacter(CharacterId)`, `openCreator(CreatorId)`, `Future<bool> requestSignIn()`.
  - **Flow:** `ComicsDetailsFlow(navigator:, comicId:)`, keyed by the id, immutable after creation. Flow state `ComicsDetailsFlowState(comicId, cover?)`; two pages: `details` and an in-flow `cover` page (the full-size cover), so the SC archetype's second page has a template.
  - **Data:** one retrofit `ComicsDetailsApi` (relative paths): `GET v1/comics/{id}`, `GET v1/characters/{id}` (the cast: the detail carries only ids, F-0040 fact 10), `GET/PUT/DELETE v1/me/favourites/comic/{id}`. Eight wire DTOs in `comic_dto.dart`, all `@Freezed(fromJson: true, toJson: true)` (R30). Domain `Comic`, `Credit`, `CastMember`, `CreatorRole` (bare `@freezed`, no JSON); mapper with `FormatException` for values outside the contract. Stateless `@injectable ComicsDetailsRepository`: the comic with its cast in parallel (a cast `404` is left out), `isFavourite` (`404` = false), `setFavourite`.
  - **Blocs (SC: 2):** `ComicDetailsBloc` (load/Retry, not found, cover, and the only caller of `openCharacter`/`openCreator`); `ComicFavouriteBloc` (signed out: awaits `requestSignIn()`, then saves; signed in: optimistic toggle with rollback; one tap at a time; `DataChanged('favourites')` once per saved write). Both states are sealed freezed unions read with `state.when` (R16); the failure cases implement `McFailureState`.
  - **Pages:** `McAppBar(leading: const McFlowBackButton())`, sections with `McSectionHeader`: header (cover, title, issue, favourite toggle), synopsis, facts (`mc_formatters`: price, page count, release day per locale), creators, characters (`McMediaCard`s). Loading, error with Retry, not found (`McEmptyView`).
  - **DI:** `ComicsDetailsDIInitializer`; root imports `[Dio, EventBus, Monitoring, SessionReader]`, hand-written for `mcgen wire` and pinned by `flow_scope_test`. **Workaround:** `_init` awaits `initializeFormatters()` first (F-0040 fact 1, marked in the code).
  - **l10n:** en, de and `en_XA`.
  - **Tests (R6, no solitary unit tests):** 2 `.feature` files (29 scenarios), `contract_test`, `flow_scope_test`, `golden_test` (5 goldens), `architecture_test`.
- **`app/wiring/publishing_wiring`**, shaped as universe_wiring: `comics_routes.dart` (`ComicDetailsRoute` `/comics/:id`) and `creators_routes.dart` (`CreatorDetailsRoute` `/creators/:id`, a placeholder flow for `openCreator`); `PublishingRouteTargets` + impl (R15; prefixed, F-0040 fact 11); `ComicsDetailsNavigatorImpl` (`@LazySingleton`, over `RouterRef`): a character goes to `AppLocations.character(id)` (the characters placeholder), a creator to its typed route, and `requestSignIn()` answers true when signed in, else shows **the temporary fixture sign-in sheet** (`src/sign_in/`, in the wiring, never in the feature; P-044); `PublishingNavigatorsDIInitializer` (injectable) and `PublishingWiringDIInitializer`; `routes_test` (11 tests).
- **`app/wiring/app_core`:** `AppLocations.comic(id)`; `appMockDomains` adds `ComicsMockDomain` and `IdentityMockDomain` (`mc_fixtures_identity` moves from dev to runtime deps).
- **`app/mini_client`:** the route comes with `publishingRoutes`; `test/comic_route_test.dart` (the link, the journey and the cast in the full app); e2e targets `comics_journey_test.dart` and `comic_deeplink_test.dart`; dev dep `mc_fixtures_comics`.
- **`characters_list` (P-068):** `CharactersListNavigator.openComic(ComicId)`; the preview lists the character's first 5 comics (`GET v1/comics?characterId=&limit=5`, `RelatedComicDto`, `RelatedComic`, its own `RelatedComicsBloc` with inline failure and Retry, the only caller of `openComic`); ARB keys in en, de, `en_XA`; feature `characters_list_related_comics.feature` (4 scenarios); contract cases for the DTO.
- **`mc_test_steps` (generic):** `I am signed in as {email}`, `the backend holds {route}`, `the backend releases {route}`, `the backend answered {route} with {status}`, `I tap {label} twice in quick succession`.

### AC → evidence
JUnit names carry the IDs (`test.xml` of each target; listed by the gates run).

| AC | Tests and evidence |
|---|---|
| AC1 | `:bdd_test` "The comic shows its cover, title, issue and synopsis", "The facts are formatted for English" (`$3.99`, `Jan 10, 1988`, `32`, `#1`), "The creators and characters sections list the comic's credits" (the fixture's credits in role order with English roles; the cast from `characterIds` with the characters fixture's names and bundled art; one request per member). `:golden_test` "T-0041-AC1 golden" top and bottom; `:flow_scope_test` "T-0041-AC1 a new comicId builds a new flow" |
| AC2 | `:bdd_test` Scenario Outline "A failed comic explains the problem and retries" × server_error, timeout, offline, malformed; "A failed cast member fails the comic, and Retry recovers"; "An unknown comic shows that it was not found" (no Retry, no exception). Goldens: error, not found |
| AC3 | `:bdd_test` "Tapping a character hands it over to the app exactly once", "Tapping a creator ..." (mocktail `called(1)` + `verifyNoMoreInteractions`). `publishing_wiring:routes_test` "T-0041-AC3 openCharacter pushes the characters placeholder location" (a push: Back returns), "... openCreator pushes CreatorDetailsRoute". `mini_client:comic_route_test` "T-0041-AC3 in the app, a cast member opens the characters placeholder". e2e `17_cast_member_placeholder.png` |
| AC4 | `:bdd_test` German: sections, favourite label, `3,99 $`, `10. Jan. 1988`, roles (`Autor`, `Coverzeichner`); German error and not found; German favourite labels and inline error. `en_XA`: every section, the cover page, the not-found page and the favourite error, with `nothing overflows`. `//tool/l10n_check:workspace_gate_test` "T-0041-AC8 the gate checks the comics_details ARB set" (a planted missing key is named) |
| AC5 | e2e on a fresh `mc-T-0041-engineer-1275` (iOS 26.2, deleted): `comics_journey_test` 10–17 (home → Characters → preview with related comics → comic page → sign-in sheet → favourite saved → cast → placeholder), `comic_deeplink_test` 18 (`miniclient://app/comics/501500`, file-drop start link) and 19 (a link sent to the running app), and the T-0033 journey 01–04 re-run: [e2e-summary](../evidence/T-0041/engineer/mini_client/e2e-summary.md), 3 of 3 PASS. `mini_client:comic_route_test` "T-0041-AC5" ×2; `publishing_wiring:routes_test` "T-0041-AC5" ×3 (route, initializer, drift); `universe_wiring:routes_test` "T-0041-AC5 openComic pushes the comic location"; `characters_list:bdd_test` "The preview lists the comics ..." and "A related comic hands over to the app exactly once"; `characters_list:contract_test` "T-0041-AC5" ×2 |
| AC6 | `:bdd_test` (`comics_details_favourite.feature`, real `mc_api_auth`, `mc_session` and identity fixtures through `McTestContainer`): signed out → `requestSignIn()` awaited (no request while pending), on true one `PUT` that left the app with the session's bearer (recording interceptor) and that the backend answered 200, the favourite stored for that user, `DataChanged('favourites')` exactly once; on false no request to `/v1/me/**` and no change; double taps (signed out and in) send one request; signed in, the toggle flips at once (held `PUT`) and a failed write rolls back with the inline error (add and remove). `publishing_wiring:routes_test` "T-0041-AC6" ×6 (sheet Sign in, Not now, dismiss, failed sign-in, already signed in, no navigator). e2e `14_sign_in_sheet.png`, `15_favourite_saved.png` |
| AC7 | `:architecture_test` (barrel exactly 5 types with `show`; every generator-read file is Flutter-free); `mc_arch_check` OK; `:flow_scope_test` "T-0041-AC7" (resolve everything; a root without `SessionReader` fails naming it; `McAppBar` + `McFlowBackButton`); `:contract_test` "T-0041-AC7" (CONTRACT shape, served comics round-trip byte for byte, mapper, every role, out-of-contract values, cast member, favourite answers). [byte identity 12 of 12 EQUAL](../evidence/T-0041/engineer/T-0041-AC7_byte_identity.md); [gen-l10n 3 of 3 identical](../evidence/T-0041/engineer/T-0041-AC7_gen_l10n_parity.md); [cutoff](../evidence/T-0041/engineer/T-0041-AC7_cutoff.md); [not committed](../evidence/T-0041/engineer/T-0041-AC7_generated_not_committed.md); fixtures check in the gates |
| AC8 | [`T-0041-AC8_gates.md`](../evidence/T-0041/engineer/T-0041-AC8_gates.md) (below) |

### Gates (AC8)
[`T-0041-AC8_gates.sh`](../../tool/checks/T-0041-AC8_gates.sh) → [**PASS**](../evidence/T-0041/engineer/T-0041-AC8_gates.md), one run, every gate:
- `test //...`: **108/108** (101 on main + 7 new targets), after an uncached run of comics_details, characters_list, `//app/...`, mc_test_steps and l10n_check;
- `build --config=lint //...`, `mc_arch_check` OK, `rules_fork.sh check` (3 patches), `dart format` 0 changed, `l10n_check` OK;
- fixtures check (T-0031-AC6; comics_details found by its glob) and the relative-path scan (T-0034-AC4);
- AC7: comics_details byte identity **12 of 12 EQUAL**, cutoff, not committed, gen-l10n parity; and for characters_list, which T-0041 changed, the T-0032 byte identity (**14 of 14**), cutoff and not-committed checks;
- **coverage: comics_details 353/353 = 100 %, publishing_wiring 88/88 = 100 %, characters_list 216/216 = 100 %, universe_wiring 38/38 = 100 %** (it was 89.5 % on the first run, a pre-existing gap: `RouteTargetsImpl` was never called by its own tests; one test added).
- Negative control: with `MC_COVERAGE_MIN=100.1` the same script [FAILS](../evidence/T-0041/engineer/T-0041-AC8_gates_negative_control.md).
- Also: `build --config=sim //app/mini_client:mini_client_ios //app/sandbox/universe_sandbox:universe_sandbox_ios` succeeds.
- AC traceability: [test_names.txt](../evidence/T-0041/engineer/test_names.txt), 63 test names carrying `T-0041-ACn` (AC1 6, AC2 8, AC3 5, AC4 7, AC5 10, AC6 12, AC7 13, AC8 2), plus the e2e targets.

### Mutations and negative controls
- [mutations.sh](../evidence/T-0041/engineer/mutations.sh) (`MC_TASK=T-0041 MC_ROLE=engineer`): **28 of 28 killed by a failing test** ([log](../evidence/T-0041/engineer/mutations.log)), 3 to 9 per AC (AC1 5, AC2 3, AC3 3, AC4 3, AC5 3, AC6 9, AC7 2); none by a compile error.
- [negative_controls.sh](../evidence/T-0041/engineer/negative_controls.sh): each check fails on its planted defect: a bare `@freezed` on `ComicDto` (DIFFER), retrofit reading `:_stage` (re-runs, 6 bloc inputs), a staged `planted.g.dart`, `nullable_getter = True` (`neg-*.md`).

### Goldens
New: 5 in comics_details (`goldens/comics_details/`), all looked at. Changed: **only** `characters_list/test/golden/goldens/character_preview.png` (the related comics section below "See full profile"; before and after in `goldens/characters_list_before/` and `_after/`). The other three characters_list goldens are unchanged.

### Edits outside the named areas (TL, please confirm)
- `app/wiring/universe_wiring` (`openComic` in the navigator impl, one test) and `app/sandbox/universe_sandbox/test/fake_targets.dart` (the fake navigator gains `openComic`): forced by the interface change.
- `tool/l10n_check` (the gate's data and one test), as T-0032 did.
- `tool/checks/`: new `T-0041-AC7_*` and `T-0041-AC8_gates.sh`; `T-0032-AC6_matches_build_runner.sh`'s expected list gains the 3 new characters_list outputs (14 of 14 EQUAL; stricter, not weaker).
- Root `pubspec.yaml`: workspace member `feature/comics/comics_details`. `pubspec.lock` and `MODULE.bazel.lock` unchanged (no new third-party package).

### Test integrity
No test deleted, skipped or weakened; no `// ignore:`. Changed existing tests: characters_list `architecture_test` expects `ComicId` in the barrel; `characters_list.feature` Background also serves `comics.default` (the preview now asks for comics); its golden test serves it too. P-080's auth pins were not lifted (no auth test touched).

### Decisions for the TL
1. **Date symbols (F-0040 fact 1):** a root `FormattersDIInitializer` (or `L10nCoreDIInitializer`) in `rootInitializers` and `McTestContainer`, or a self-initialising `mc_formatters`; then the feature initializer returns to Tide's shape.
2. **The cast needs N requests (F-0040 fact 10):** keep, or embed a cast summary in the comics contract.
3. **`/creators/:id` placeholder** in publishing_wiring for `openCreator` (not in the task text).
4. **Per-group route-target names** (`PublishingRouteTargets`; F-0040 fact 11) for the bricks; rename universe's later?
5. The temporary sheet's copy is English only.

### Follow-ups (for `pending-work.md`)
- The favourite does not react to a sign-in or sign-out elsewhere while the page is open (listen to `SessionReader.authState` / `DataChanged('favourites')`).
- `RecordedRequest.headers` in `mc_test_utils` (F-0040 fact 4).
- `publishing_sandbox` (P1-18 lists it; not in this task's scope).
- A deep-linked comic at the app root has no back button (as F-0035 accepts for any flow root).
- `mcgen wire` for `flow_scope.dart` (as T-0032).
