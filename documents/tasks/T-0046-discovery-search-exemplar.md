# T-0046: `discovery_search` exemplar (SR archetype), P1-19

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (**Opus**: first SR exemplar, which the bricks copy; ADR-0011) |
| Verifier | crew: Verifier, **Opus tier** (exemplar) |
| Branch | `fleet/T-0046-discovery-search` |
| Created | 2026-11-26 |
| Depends on | T-0030 (`mc_paging`: `DebouncedQuery`, `SearchHistory`), T-0032/T-0041 (LD and SC exemplars), T-0043 (`mc_fixtures_discovery`), T-0044 (`mc_ds_inputs`: `McSearchField`, `McChipGroup`) |
| Related | plan 01 F074, P1-19 (EX-AC1–6), §3.3, §4; ADR-0007, ADR-0010, ADR-0011; R4, R6, R15–R17, R30; F-0031, F-0036, F-0040, F-0043 |

## Goal
The third archetype exemplar, **search (SR)**: `feature/discovery/discovery_search`. You type into `McSearchField`. One debounced request goes out, and the results come back grouped by domain (characters, then comics) with a type filter (`McChipGroup`). Your recent searches are remembered. Tapping a result opens the character or the comic.

As with T-0032 and T-0041, this package is the shape the P1-24 bricks copy for every SR feature. It must match the established exemplar shapes, with no workarounds.

## Scope
- **In:**
  - **`feature/discovery/discovery_search`:**
    - **Flow and navigator:** `DiscoverySearchFlow` (optional initial query arg). `DiscoverySearchNavigator` with `openCharacter(CharacterId)` and `openComic(ComicId)`.
    - **API and repository:** a retrofit API for `GET v1/search` and `v1/search/suggestions`, and a stateless repository.
    - **State:** a freezed sealed state: `idle` (with recent history), `searching`, `results` (grouped), `empty`, `failure`.
    - **Bloc:** `mc_paging`'s `DebouncedQuery` (300 ms) and `SearchHistory` (cap 10, on `mc_storage`).
    - **UI:**
      - `McAppBar(leading: const McFlowBackButton())` with the search field.
      - Type chips: All, Characters, Comics.
      - Grouped results built from `McSectionHeader` and `McMediaCard`, or a list row.
      - The recent-history list with clear.
    - **Tests and strings:** l10n in en and de. BDD, contract tests and goldens; no solitary unit tests (R6).
    - **No stale results:** results for an older query must never replace newer ones. Rapid typing, a slow response arriving after a newer one, and clearing while a request is in flight must all end on the latest query's state.
  - **`app/wiring/discovery_wiring`:**
    - the `/search` route (optional `?q=`)
    - the navigator implementation, pushing the universe and publishing locations through `AppLocations`
    - `AppLocations.search(q)` and the drift test
  - **`mini_client`:**
    - a Search entry on home
    - the deep link `miniclient://app/search?q=spi`
    - the discovery mock domain in `appMockDomains`
- **Out:** paging of results beyond the first page per group (a "see all" link per group is allowed as a placeholder), voice search, recommendations and trending.

## Acceptance criteria
- **T-0046-AC1 (EX-AC1):** Given `discovery.default`, when I type "spi", then the results show grouped as characters then comics, in the documented ranking, each with its title and art. BDD.
- **T-0046-AC2 (EX-AC2):** Given `server_error`, then an error with Retry shows, and Retry recovers with the same query. Given a query with no hits, then the empty state shows. A query under 2 characters makes no request. BDD.
- **T-0046-AC3 (EX-AC3):** When I tap a character result, then `openCharacter(id)` is called exactly once; the same for a comic and `openComic`. The wiring test pushes the right location for each. BDD plus a wiring test.
- **T-0046-AC4 (EX-AC4):** Given locale `de`, then the hints, chips, section titles, empty and error states are German. Given `en_XA`, then nothing overflows.
- **T-0046-AC5 (EX-AC5):** The mini_client e2e: home → Search → type "spi" → results → tap a comic → the comic page; and the deep link `miniclient://app/search?q=spi`. With screenshots.
- **T-0046-AC6 (P1-19 AC6):** Given typing "spi" one character at a time within the debounce window, then exactly one request fires, for "spi". Results are grouped by domain, and the query is saved in history (most recent first, de-duplicated, cap 10). It survives a new flow instance. Also:
  - Rapid typing, then a slow response for an old query arriving after the new one, ends on the new query's results.
  - Clearing the field while a request is in flight shows the history, not stale results.
  - The type chips refilter with one request (or none, if filtering is done client-side; document which).

  BDD under fake time, with held and released responses through `McBackendHarness`.
- **T-0046-AC7 (architecture and codegen):**
  - `mc_arch_check` passes.
  - The barrel exports only the flow, the navigator and arg types.
  - Nothing generated is committed, and outputs are byte-identical to build_runner's.
  - The cutoff check passes.
  - The fixtures check passes.
  - Globs use `MC_GENERATED_DART`, and `T-0042-AC4_safety.sh` passes after `tool/ide_sync`.
- **T-0046-AC8 (gates):** Package coverage is ≥ 90 %. `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and `l10n_check` pass, and everything is traceable by `T-0046-ACn`.

## Log
- 2026-11-26: Created (TL); dispatched after T-0044 merged.
- 2026-11-26 (Engineer): Branched from `origin/main` `5cdb28c`. Every generator built on the first try: **no codegen shim failed on a real-world case** (an injectable `@module`, a freezed union with public cases and `includeIfNull: false` are new; F-0046 fact 1). Two test-kit gaps found on the way and fixed in `mc_test_steps` (generic steps): queued real storage writes needed more rounds of real time (F-0046 fact 2), and there was no way to type character by character or to let a set amount of fake time pass.
- 2026-11-27 (Engineer): Merged `origin/main` `f624f21` (T-0045, T-0047); `fvm flutter pub get --offline` left both locks unchanged. Gates, safety and e2e re-run on the merged tree. Handed off; evidence in `documents/evidence/T-0046/engineer/`.

## Outcome
**Handed off** for review and verification on `fleet/T-0046-discovery-search`. Finding: [F-0046](../findings/F-0046-search-exemplar.md). Evidence: [`documents/evidence/T-0046/engineer/`](../evidence/T-0046/engineer/).

### What was built
- **`feature/discovery/discovery_search`** (SR), in plan 01 §3.3's layout and the LD/SC exemplars' shapes:
  - **Barrel:** `DiscoverySearchFlow`, `DiscoverySearchNavigator`, and the argument types `CharacterId`, `ComicId` (extension types; R4).
  - **Navigator:** `openCharacter(CharacterId)`, `openComic(ComicId)`.
  - **Flow:** `DiscoverySearchFlow(navigator:, initialQuery:)`, keyed by the query, immutable after creation; flow state `DiscoverySearchFlowState(initialQuery)`; one page, `search`.
  - **Data:** retrofit `DiscoverySearchApi` (relative paths): `GET v1/search?q=&limit=` and `GET v1/search/suggestions?q=`. Five wire DTOs in `search_dto.dart`, all `@Freezed(fromJson: true, toJson: true)` (R30). Domain `SearchResults`, `SearchGroup`, `SearchHit` (a sealed union: `CharacterHit`, `ComicHit`), `SearchType`, `SearchFilter`; mapper with `FormatException` for values outside the contract (unknown type or variant, a result in the wrong group). Stateless `@injectable DiscoverySearchRepository.search(query)` (first page of 20 per group).
  - **Recent searches:** `mc_paging`'s `SearchHistory` (cap 10, key `discovery_search.history`) on the root `FileStore`, registered by an injectable `@module` (`di_module.dart`) as a lazy singleton per flow scope.
  - **Bloc (one):** `DiscoverySearchBloc` over `DebouncedQuery` (300 ms). States `idle(history)`, `searching`, `results(query, results, filter)`, `empty`, `failure` (`McFailureState`), read with `state.when` (R16). Every search, clear and too-short query starts a new generation, and an answer shows only while its generation is current (F-0046 fact 7). Queries under 2 characters send nothing. A search that found something is saved; each history change has a version and only the latest one's answer is shown. One Retry at a time.
  - **Type filter: client-side** (the AC's "or none" case). One request answers both groups; a chip, or a section's "See all N", changes what shows and sends no request. Under "All" each section shows 5 rows; under one type, the whole first page and "Showing 20 of N". The chip stays for the next query.
  - **UI:** `McAppBar(leading: const McFlowBackButton())`, the `McSearchField` below it (in the body, so its height follows the text scale), `McChipGroup.single` (All, Characters, Comics), sections from `McSectionHeader` with list rows (`ListTile` with `McImage` art, title, team or year), recent searches with Clear, `McLoading`, `McEmptyView`, `McErrorView` with Retry.
  - **l10n:** en, de and `en_XA` (18 keys; the shared error copy from `mc_l10n_core`).
  - **Tests (R6, no solitary unit tests):** 3 `.feature` files (32 scenarios, 35 tests with the outline's examples), `contract_test` (10), `flow_scope_test` (4), `golden_test` (5 goldens), `architecture_test` (3).
- **`app/wiring/discovery_wiring`**, shaped as publishing_wiring: `search_routes.dart` (`SearchRoute` `/search`, optional `q`), `DiscoveryRouteTargets` + impl (R15; group prefix), `DiscoverySearchNavigatorImpl` (`@LazySingleton`, over `RouterRef`; both targets are other groups', so `AppLocations.character` / `AppLocations.comic`, each a push), `DiscoveryNavigatorsDIInitializer` (injectable) and `DiscoveryWiringDIInitializer` (navigators + route targets). `discoveryRoutes` is now a getter. `routes_test` (10 tests, drift table included).
- **`app/wiring/app_core`:** `AppLocations.search([query])` (the query as an encoded parameter), `DiscoveryMockDomain` in `appMockDomains` (`mc_fixtures_discovery` becomes a runtime dep); 2 tests in `boot_test`.
- **`app/mini_client`:** a Search button on home (`context.push(AppLocations.search())`); `test/search_route_test.dart` (the link, a cold-start link, home → Search → a comic, a character → the placeholder); e2e targets `search_journey_test.dart` and `search_deeplink_test.dart`; dev dep `mc_fixtures_discovery`.
- **`mc_test_steps` (generic):** `I type {text}`, `I type {text} one character at a time`, `{n} milliseconds pass`, `I tap the icon button {label}`, `the field reads {text}`, `the app can no longer write to storage`; `the app finishes writing to storage` now runs until the storage directory stops changing (`mcFinishStorageIo`, exported; never fewer rounds than before; F-0046 fact 2).

### AC → evidence
JUnit names carry the IDs (`test.xml` of each target; listed by the gates run).

| AC | Tests and evidence |
|---|---|
| AC1 | `:bdd_test` "Typing a name shows its characters, then its comics, in the backend's ranking" (both sections in order, 5 + 5 rows equal to the fixture index's own ranking, with title, subtitle and bundled art; `See all 152`, `See all 400`; one request `q=spi&limit=20`), "A type chip shows one type's whole first page and sends no request" (20 + 20 rows, "Showing 20 of N"), "See all on a section picks its chip", "The chosen chip stays for the next query", "A name only one type has shows the other section as empty". `:contract_test` "T-0046-AC1" ×2 (repository: both groups, typed ids, served art; `limit` asked for). Goldens: results under All and under Comics |
| AC2 | `:bdd_test` Scenario Outline "A failed search explains the problem, and Retry searches the same query again" × server_error, timeout, offline, malformed; "A double Retry sends one request"; "A name nothing matches shows that nothing was found"; "A query under 2 characters sends no request" (`s`, ` s ` → 0 requests, `sp` → 1); "Shortening the query under 2 characters hides the results"; the fixture sets: "Given the server_error set, a search shows the error with Retry" (500 from the backend), "Given the empty set, every name finds nothing". `:contract_test` "T-0046-AC2" ×2. Goldens: nothing found, failed |
| AC3 | `:bdd_test` "Tapping a character hands it over to the app exactly once", "Tapping a comic ..." (mocktail `called(1)` + `verifyNoMoreInteractions`). `discovery_wiring:routes_test` "T-0046-AC3 openCharacter pushes the character location, and Back returns to the search", "... openComic ...". `mini_client:search_route_test` "T-0046-AC3 in the app, a character result opens the character placeholder" |
| AC4 | `:bdd_test` German: title, field label, hint, chips, sections, `Alle 152 anzeigen`, `20 von 152 angezeigt`, the empty-section note, nothing found, the error and Retry, the recent searches. `en_XA`: every state (hint, results, one type, empty section, nothing found, recent searches, failure) with `nothing overflows`. `//tool/l10n_check:workspace_gate_test` "T-0046-AC8 the gate checks the discovery_search ARB set" (a planted missing German key is named) |
| AC5 | e2e on a fresh `mc-T-0046-engineer-30982` (iOS 26.2, deleted): `search_journey_test` 30–35 (home → Search → "spi" → grouped results → Comics chip → comic page → back → recent search) and `search_deeplink_test` 36 (`miniclient://app/search?q=spi`, file-drop start link) and 37 (a link sent to the running app); the T-0033 and T-0041 journeys re-run: [e2e-summary](../evidence/T-0046/engineer/mini_client/e2e-summary.md), 7 of 7 PASS. `mini_client:search_route_test` "T-0046-AC5" ×3; `discovery_wiring:routes_test` "T-0046-AC5" ×8 (route with and without a query, encoded queries, the link form, initializer, drift); `:bdd_test` "A search opened with a query searches it once typing would have paused"; `:flow_scope_test` "T-0046-AC5 a new initialQuery builds a new flow that searches it"; `app_core:boot_test` "T-0046-AC5" ×2 |
| AC6 | `:bdd_test` (`discovery_search_typing.feature`, fake time, held and released answers through `McBackendHarness`): one request for "spi" typed a character at a time, none at 299 ms, one at 300 ms; a pause inside the word sends one per pause; a slow answer for "spire" released after "spin" was answered; both held and released in reverse order; clearing the field while "spi" is held shows the recent searches and the late answer is dropped (and not saved); shortening to "s" while held; saved most recent first, without repeats, at most 10, and a search that found nothing is not saved; the list survives a new flow; a tapped recent search is searched again; Clear forgets them for the next flow too; a clear while a save is still on its way wins; a save that fails keeps the list. Chips: see AC1 (also tagged AC6). Golden: recent searches |
| AC7 | `:architecture_test` (barrel exactly 4 types with `show`; every generator-read file is Flutter-free); `mc_arch_check` OK; `:flow_scope_test` "T-0046-AC7" ×3 (resolve everything; a root without `FileStore` fails naming it; `McAppBar` + `McFlowBackButton`); `:contract_test` "T-0046-AC7" ×6 (CONTRACT shape, six served answers round-trip byte for byte, the absent subtitle, suggestions, out-of-contract values, malformed). [byte identity 11 of 11 EQUAL](../evidence/T-0046/engineer/T-0046-AC7_byte_identity.md); [gen-l10n 3 of 3 identical](../evidence/T-0046/engineer/T-0046-AC7_gen_l10n_parity.md); [cutoff](../evidence/T-0046/engineer/T-0046-AC7_cutoff.md) (a bloc body edit runs the bloc's freezed action and the shards, not the aggregate, retrofit or json); [not committed](../evidence/T-0046/engineer/T-0046-AC7_generated_not_committed.md); fixtures check in the gates. `MC_GENERATED_DART` in every `lib/**` glob of the feature and the wiring; after `tool/ide_sync --env dev` (45 files) [`T-0042-AC4_safety.sh`](../evidence/T-0046/engineer/T-0042-AC4_safety.md) **PASS** (0 actions and 0 of 134 tests executed on the synced tree, 46,460 outputs byte-identical); `tool/ide_sync --clean` removed 81 files. `fvm flutter analyze` over the touched packages on the synced tree (integration tests included): no issues |
| AC8 | [`T-0046-AC8_gates.md`](../evidence/T-0046/engineer/T-0046-AC8_gates.md) (below) |

### Gates (AC8)
[`T-0046-AC8_gates.sh`](../../tool/checks/T-0046-AC8_gates.sh) → [**PASS**](../evidence/T-0046/engineer/T-0046-AC8_gates.md) on the merged tree, one run, every gate:
- `test //...`: **134/134**, after an uncached run of `//feature/...` (the shared storage step changed, so comics_details and characters_list re-ran too), `//app/...`, `mc_test_steps`, `l10n_check` and `mc_arch_check`;
- `build --config=lint //...`, `mc_arch_check` OK, `rules_fork.sh check`, `dart format` 0 changed, `l10n_check` OK, the fixtures check (T-0031-AC6) and the relative-path scan (T-0034-AC4);
- AC7: byte identity 11/11, cutoff, not committed, gen-l10n parity;
- **coverage: discovery_search 294/294 = 100 %, discovery_wiring 22/22 = 100 %.** `app_core` is **85.3 % (243/285), under 90 % before this task** (`route_probe.dart`, `stub_page.dart` and parts of the boot and backend initializers have no test in app_core's own targets; they are exercised from the apps). Every line T-0046 added to app_core is covered (the 2 new `boot_test` tests). The run without an exemption [fails on it](../evidence/T-0046/engineer/T-0046-AC8_gates_without_exemption.md); the passing run sets `MC_COVERAGE_EXEMPT=app/wiring/app_core`. **TL decision needed** (below).
- Also: `tool/ide_sync --env dev`, `fvm flutter analyze` (no issues), `T-0042-AC4_safety.sh` PASS, `tool/ide_sync --clean` (AC7).
- AC traceability: [test_names.txt](../evidence/T-0046/engineer/test_names.txt), 70 test names carrying `T-0046-ACn` (AC1 15, AC2 14, AC3 5, AC4 5, AC5 15, AC6 14, AC7 13; AC8 is the gates run and the l10n gate test), plus the e2e targets.

### Mutations
[mutations.sh](../evidence/T-0046/engineer/mutations.sh) (`MC_TASK=T-0046 MC_ROLE=engineer`): **46 of 46 killed by a failing test**, none by a compile error, 2 to 15 per AC (AC1 9, AC2 5, AC3 4, AC4 3, AC5 5, AC6 15, AC7 4, golden 1). Every AC6 race has its own: no debounce, a 200 ms debounce, no generation check (stale answer), a clear that does not bump the generation, a clear that keeps the old state, a too-short query that does not bump it, a chip that sends a request, no save, saving empty searches, no history version check, Clear not clearing storage, a tapped recent search not searched, a failed save emptying the list, cap 11, a per-flow history key.
- [Run 1](../evidence/T-0046/engineer/mutations-run1.log): 44 of 46. AC3-a was a compile error (the bloc does not import `CharacterId`; re-expressed in the mapper), and **AC6-i survived**: the cap scenario typed "zzzz" early enough that the cap dropped it either way. The scenario now types it late, so a saved empty search would stay on the list. [Run 2](../evidence/T-0046/engineer/mutations-run2.log) (`MC_ONLY="AC3-a AC6-i"`): both killed.
- A first attempt reported 0 of 46: the script used `HOME` as a variable name (F-0046 fact 11). Its classifier now refuses to call a run without a failing test a kill or a survivor.
- One guard has no mutation: the version check on the **initial** history read. A read started at flow open always ends before a later save's read-write-rename chain, so no test can make the old read land last; it stays as a guard against a reordered completion (stated in the bloc's doc).

### Goldens
New: 5 in discovery_search (`test/golden/goldens/`: recent searches, results under All, under Comics, nothing found, failed), all looked at. The caret is steady in goldens (`EditableText.debugDeterministicCursor`, F-0046 fact 9). No other golden changed.

### Edits outside the named areas (TL, please confirm)
- Root `pubspec.yaml`: workspace member `feature/discovery/discovery_search`. `pubspec.lock` and `MODULE.bazel.lock` unchanged (no new third-party package).
- `tool/l10n_check` (the gate's data and one test), as T-0032 and T-0041 did.
- `tool/checks/`: new `T-0046-AC7_*` and `T-0046-AC8_gates.sh`.
- `app/wiring/app_core/test/boot_test.dart`: 2 new tests (for the location and the mock domain this task added).

### Test integrity
No test deleted, skipped or weakened; no `// ignore:`. Changed shared test code: `the app finishes writing to storage` runs the same 10 rounds as before and then continues until the storage directory is unchanged for 25 rounds (stricter, never shorter); comics_details' scenarios that use it pass unchanged.

### Decisions for the TL
1. **`GET /v1/search/suggestions` is in the API (as the scope says) but the UI does not call it.** Results show as you type, so a suggestions list would repeat the first titles and add a second request per pause, which breaks "exactly one request fires, for 'spi'". The endpoint is contract-tested (`T-0046-AC7: the suggestions answer round-trips byte for byte`). Options: keep it as the brick's third endpoint, use it for a type-ahead before results (and restate AC6 as "one search request"), or drop it from the exemplar.
2. **`app_core` coverage 85.3 % (pre-existing):** a follow-up to test `route_probe`, `stub_page` and the initializers in app_core itself, or accept the exemption.
3. **`DebouncedQuery.submit(text)`** in `mc_paging`, so a tapped recent search and a linked query are searched at once instead of after 300 ms (F-0046 fact 6).
4. The search field sits below `McAppBar` in the body (not in the app bar's `bottom`), so its height follows the text scale; the bar keeps the title "Search".

### Follow-ups (for `pending-work.md`)
- `discovery_sandbox` (P1-19 lists it; not in this task's scope), as P-082 for publishing.
- A same-frame double tap on a result calls the navigator twice (intents are fire-and-forget; comics_details' cast has the same shape).
- A query of two bare combining marks passes the client's 2-character check and gets the backend's `400`, shown as "Something went wrong" with Retry (the contract folds before counting).
- Stale requests are not cancelled (in-process backend; F-0046 fact 7).
