# T-0071: `characters_search`, name-prefix search over characters with facets and history (F003)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-28 `8e45bf30`; review-first and merge gates per ADR-0015) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates |
| Branch | `fleet/T-0071-characters-search` |
| Created | 2026-11-28 |
| Depends on | T-0046 (`discovery_search`, the SR exemplar), T-0032 (`characters_list`), T-0067 (`characters_details`), T-0030 (`mc_paging`: `DebouncedQuery`, `SearchHistory`) |
| Related | plan 01 F003 (SR/M); `mc_fixtures_characters` `GET /v1/characters?nameStartsWith=&orderBy=&offset=&limit=`; F-0046 |

## Goal
Add a character-only search: type a prefix, get matching characters, and filter by facets. It is a copy of the SR exemplar's shapes (`discovery_search`), aimed at one domain with paging.

## Scope
- **In: `feature/characters/characters_search`.**
  - **Flow and navigator:**
    - `CharactersSearchFlow` takes an optional initial query.
    - `CharactersSearchNavigator.openCharacter(CharacterId)` opens the `characters_details` profile.
  - **API and repository:** `GET /v1/characters` with `nameStartsWith`, `orderBy`, `offset` and `limit`.
  - **Facets:** sort chips (Name A–Z, Z–A, and any other order the fixture supports). If the fixture can filter by alignment or team, add a facet chip group; if it can't, add the filter to `mc_fixtures_characters` with tests. Keep the existing characters tests green.
  - **Debounce and history:** `mc_paging` `DebouncedQuery` at 300 ms, and a separate `SearchHistory` instance (cap 10, on `mc_storage`) with its own storage key.
  - **Paging:** results page as you scroll (`mc_paging`).
  - **States:** idle (history), searching, results, empty, and failure with Retry.
  - **No stale results:** results for an older query never replace newer ones. Copy the SR exemplar's generation guard and its held-response tests.
  - **Tests and strings:** l10n in en and de. BDD tests, plus unit tests for pure logic. **No goldens.**
  - **Analytics:** the screen is named `characters_search`.
- **In: `universe_wiring`.**
  - A `/characters/search?q=` route nested under home, plus `AppLocations.charactersSearch(q)` and its drift test.
  - A search action in the characters list app bar opens it. This is a small, documented change to `characters_list`'s navigator: one new method, `openSearch`.
- **Out:** global search (`discovery_search` already covers it), recommendations.

## Acceptance criteria
- **T-0071-AC1:** Given `characters.default`, typing a prefix shows the matching characters, sorted by name, with art. A query that matches nothing shows the empty state. BDD.
- **T-0071-AC2:**
  - Typing one character at a time within the debounce window sends exactly one request.
  - A slow old response arriving after a newer query never shows.
  - Clearing the query while a request is in flight shows history.
  - The history is de-duplicated, most recent first, capped at 10, and survives a new flow instance.
  - Under fake time with held responses.
- **T-0071-AC3:**
  - A facet or sort change sends one request and resets the paging.
  - The next page loads at the end of the list.
  - `server_error` shows Retry, and Retry recovers.
- **T-0071-AC4:**
  - Tapping a result calls `openCharacter` exactly once, with the double-tap guard.
  - The wiring pushes the profile location.
  - The characters list's search action opens the search.
  - `de` and `en_XA` at 1× and 2× text scale, with no overflow.
- **T-0071-AC5:** E2E on your own simulator: home → Characters → Search → type → open a character → Back → Back. Also the cold link `miniclient://app/characters/search?q=a`. Take screenshots.
- **T-0071-AC6:** Gates:
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, the format gate, `l10n_check`, and `T-0042-AC4_safety.sh` after `tool/ide_sync`;
  - the 50-run flake check on the debounce, history and race targets;
  - every cited test exists.

## Log
- 2026-11-28: Created and dispatched (TL), as part of the second hybrid wave.
- 2026-11-28 (Engineer): Branched from `origin/main` `c1b08371`. Added the `team` filter to `mc_fixtures_characters`, built `feature/characters/characters_search` from the SR exemplar's shape, wired it in `universe_wiring` and added the `characters_list` app-bar action. Merged `origin/main` `e8834760` (docs only). Gates, 50-run flake check, `T-0042-AC4_safety.sh` and the e2e run are in [`documents/evidence/T-0071/engineer/`](../evidence/T-0071/engineer/). Finding: [F-0071](../findings/F-0071-characters-search.md).

## Outcome
**Handed off** for review on `fleet/T-0071-characters-search`. Finding: [F-0071](../findings/F-0071-characters-search.md). Evidence: [`documents/evidence/T-0071/engineer/`](../evidence/T-0071/engineer/).

### What was built
- **`feature/characters/characters_search`** (SR, copies `discovery_search`; ADR-0015: BDD, a contract test, a flow-scope test and an architecture test, no goldens):
  - **Barrel:** `CharactersSearchFlow(navigator:, initialQuery:)`, `CharactersSearchNavigator.openCharacter(CharacterId)`, `CharacterId`.
  - **Data:** retrofit `CharactersSearchApi` (`GET v1/characters` with `nameStartsWith`, `orderBy`, `team`, `offset`, `limit`; a null `team` is left out), `CharacterDto`, a stateless `CharactersSearchRepository.fetchPage`.
  - **Facets:** sort chips (Name A-Z, Name Z-A, Recently updated, Least recently updated = `name`, `-name`, `-modified`, `modified`) and a team chip group (the eight teams; tapping the chosen one again clears it). The backend applies both.
  - **Bloc:** `DebouncedQuery` (300 ms), `SearchHistory` (cap 10, key `characters_search.history`, its own instance), one `PagingController` per search, a generation guard. States `idle(history)`, `searching`, `results(page)`, `empty`, `failure`; the facet chips show in all but `idle`.
  - **Flow:** one page, the screen `characters_search` (`AnalyticsFlowObserver`).
  - **l10n:** en, de and en_XA (20 keys); the shared error copy from `mc_l10n_core`.
- **`mc_fixtures_characters`:** `GET /v1/characters?team=` (a team id such as `harbor-watch`, `teamIdOf`; case-insensitive; empty is no filter; an unknown id is `total: 0`). CONTRACT.md updated (the query table and a "Teams" row). No snapshot changed, no existing test edited; 3 new tests (`T-0071-AC3`).
- **`universe_wiring`:** `CharactersSearchRoute` (`/characters/search?q=`, name `characters_search`, nested under `/characters` before `:id`), `UniverseRouteTargets.charactersSearch({query})`, `CharactersSearchNavigatorImpl` (pushes `CharacterDetailsRoute`), `CharactersListNavigatorImpl.openSearch` (pushes `CharactersSearchRoute`). **`app_core`:** `AppLocations.charactersSearch([query])`.
- **`characters_list`:** the one new navigator method `openSearch()`, a bloc event `openSearch` (with a 500 ms double-tap guard), the app-bar action (`McIconButton`, tooltip "Search characters"), one l10n key `charactersListSearch` (en, de, en_XA).
- **`mini_client`:** `test/characters_search_route_test.dart` (the real app: cold link, running-app link, list -> search -> profile) and two e2e targets.

### AC -> evidence
JUnit names carry the IDs. Everything below passes in `test //...` (241 of 241) and in the 50-run check.

| AC | Tests and evidence |
|---|---|
| AC1 | `characters_search:bdd_test` `characters_search.feature`: "Typing a prefix shows the matching characters, sorted by name, with their art" (one request `nameStartsWith=spi&orderBy=name&offset=0&limit=30`, the first 30 rows equal the fixture's name order, each with its bundled art, sort A-Z chosen, no team), "The prefix matches in any case and is trimmed", "A prefix nothing matches shows the empty state", "Clearing the field shows the recent searches again", "The screen is named characters_search" (`the screen {'characters_search'} was tracked`), "A search opened with a query searches it at once", "...blank query...". `:contract_test` "T-0071-AC1" x5 (the CONTRACT.md example, byte round trip, unknown variant, repository page = fixture cast, the request's query parameters). `:flow_scope_test` "T-0071-AC1 a new initialQuery builds a new flow that searches it" |
| AC2 | `characters_search_typing.feature` (fake time, held and released answers): one request for "spi" typed a character at a time (none at 299 ms, one at 300 ms), the Search key, a pause inside the word, a slow answer for "spire" after "spin", reverse order, clearing while in flight shows history and drops the late answer, a cleared query is not saved, history: most recent first / no repeats / cap 10 / a no-match is not saved, survives a new flow, a tapped recent search searches at once, Clear (also for the next flow), a failed save and a failed Clear keep the list, a facet change does not save again. `:flow_scope_test` "T-0071-AC2 the recent searches live under the key characters_search.history" (and the global search's key stays empty) |
| AC3 | `characters_search_facets.feature`: every sort sends exactly one request (offset 0) and shows that order; a sort change after page 2 starts over (no `offset=30` request for the new order); a team keeps its characters (8 of "amber") and clears; team + sort combine; a team with no match says so and its chip brings the matches back; facets stay for the next query; scrolling to the end loads page 2 once, a short list asks for none; `server_error`, `timeout`, `offline`, `malformed` each show the error with Retry, and Retry recovers the same query; a double Retry sends one request; a failed second page keeps the rows and offers Retry; a failed facet change shows the failure and Retry brings that order back. `:contract_test` "T-0071-AC3" x4 (every sort sorts as its wire name says, the team chips equal the cast's teams, a team query, `CharacterFacets`) and a server error is a value. `mc_fixtures_characters:characters_test` "T-0071-AC3" x3 |
| AC4 | `characters_search_open.feature`: a tap calls `openCharacter` once (mocktail `called(1)` + `verifyNoMoreInteractions`), a double tap in one frame once, 499 ms once, 501 ms twice, a result on page 2; German (field, hint, chips, empty with team, failure, Retry, recent searches) and `en_XA` (every state) at 1x and 2x text scale with `nothing overflows`. `universe_wiring:routes_test` "T-0071-AC4" x3 (the list's `openSearch` pushes `/characters/search` and Back returns; the search's `openCharacter` pushes the profile and Back returns; the targets build the flow with the wiring navigator). `characters_list:bdd_test` `characters_list_search.feature` x4 (the action calls `openSearch` once, a double tap once, German at 2x, `en_XA` at 2x). `mini_client:characters_search_route_test` "T-0071-AC4" (the real app: Characters -> Search action -> type -> a result opens the profile, Back returns to the results) |
| AC5 | e2e on `mc-T-0071-engineer-30498` (iOS 26.2, deleted): [e2e-summary](../evidence/T-0071/engineer/mini_client/e2e-summary.md), 3 of 3 PASS: `characters_search_journey_test` (home -> Characters -> Search -> "amber" -> Name Z-A -> a character -> profile -> Back -> Back; screenshots 90 to 96), `characters_search_deeplink_test` (cold `miniclient://app/characters/search?q=a`, Back to the list, Back to home, then a link to the running app; screenshots 97 to 99), and the existing `characters_journey_test` (the changed list app bar). In `test //...`: `universe_wiring:routes_test` "T-0071-AC5" x3 (the link with and without `q`, an encoded query), `mini_client:characters_search_route_test` "T-0071-AC5" x2, and the drift table in `routes_test` (T-0033-AC2) |
| AC6 | [gate logs](../evidence/T-0071/engineer/): `test --lockfile_mode=error //...` 241 of 241 ([test_all.log](../evidence/T-0071/engineer/test_all.log)), `build --config=lint //...`, `mc_arch_check` OK, `rules_fork.sh check`, the format gate (0 changed), `l10n_check` OK, the fixtures check and the relative-path scan, `T-0042-AC4_safety.sh` **PASS** after `tool/ide_sync` ([safety](../evidence/T-0071/engineer/T-0042-AC4_safety.md)), `fvm flutter analyze` clean on the synced tree for characters_search, characters_list, universe_wiring, universe_sandbox, app_core and mini_client (integration tests included). **50 runs, uncached, 0 failures** ([flake_50.log](../evidence/T-0071/engineer/flake_50.log)): `characters_search:bdd_test` (the debounce, history and race scenarios), `:flow_scope_test`, `:contract_test`, `characters_list:bdd_test`, `universe_wiring:routes_test`, `mini_client:characters_search_route_test`. Architecture: `:architecture_test` "T-0071-AC6" x3; `//tool/l10n_check:workspace_gate_test` "T-0071-AC6 the gate checks the characters_search ARB set". Every `T-0071-ACn` name cited here exists (grepped) |

### Fixture changes
`mc_fixtures_characters`: the `team` query parameter on `GET /v1/characters` (handler, CONTRACT.md, 3 tests). Deterministic (a filter over the existing cast), additive (no snapshot, field or default moved), and every existing fixture test passes unchanged. Side effect: `characters_list` also sent `team` (its `initialTeamId`) and the fixture ignored it; it now filters by the same team id, and the review round added a `characters_list` scenario that asserts the rows (`characters_list_team.feature`, `T-0071-AC3`).

### Existing tests touched (every edit is forced by a new method or route; nothing deleted, skipped or weakened, no `// ignore:`)
- `characters_list`: **no test edited.** The three goldens `characters_list_loaded.png`, `characters_list_error.png` and `characters_list_empty.png` changed by 151 px each (the new app-bar icon) and were regenerated (`--update-goldens`); `character_preview.png` is unchanged. Before and after: [goldens/](../evidence/T-0071/engineer/goldens/).
- `universe_wiring/test/routes_test.dart`: `_Targets` implements the new `charactersSearch`; the drift table gained the search entries, and its count check was first weakened to `drift.length - 2`; the review round replaced it with a `template` per row and an equality of the table's templates with the full path templates of every route (a missing route fails again).
- `universe_sandbox/test/fake_targets.dart`: `NoNavigator.openSearch` and `FakeTargets.charactersSearch`.
- `mini_client/test/analytics_screens_test.dart`: `'characters_search'` in `_expectedRouteNames`.
- `tool/l10n_check`: the BUILD data and one new test, as T-0046 did.
- Root `pubspec.yaml`: workspace member `feature/characters/characters_search`. `pubspec.lock` and `MODULE.bazel.lock` unchanged.
- T-0070 also edits `account_wiring`, `AppLocations` and home: here `AppLocations` gets one new member and `analytics_screens_test.dart` one new set entry; a merge conflict there is mechanical.

### Decisions and notes for the TL
1. **The team facet** is a chip group of the eight names in CONTRACT.md (kept in the feature as `characterTeams`, with a contract test against the cast). The fixture has no "alignment".
2. **Any non-blank query is searched** (one letter is a prefix); the exemplar's 2-character minimum is for a ranked full-text search.
3. **Retry** repeats the failed request only (`PagingController.retry`): the first page, or the failed later page.
4. **Pull to refresh** reloads the first page of the same search (kept from the list; not an AC).

### Review round (single fix round)
1. `team` has one meaning, the team id (above). `characters_list` test opens with `harbor-watch` and asserts the first 30 rows are that team's; a second scenario (`red`) shows the empty state. CONTRACT.md updated.
2. The flow trims `initialQuery` (key, field and search use one text). Tests: BDD "A linked query is trimmed" and `flow_scope_test` "a linked query with spaces is the same flow as the trimmed one".
5. `emptySearchMessage` is the one helper for the `empty` state and the paged list's empty view.
6. The drift check counts route templates (see above).
Re-run: gates, 50 runs of the changed targets, `characters_journey_test`.

### Follow-ups (for `pending-work.md`)
- The list's team is not passed to `openSearch` (the search opens on all teams); deliberate for now.
- The open guards (list and search, 500 ms) are not reset when their route becomes current again.
- Stale requests are not cancelled (in-process backend; as F-0046 fact 7).
- `universe_sandbox` still stubs the search; its links test does not cover `/characters/search`.

## Merge (TL)
- 2026-11-28: `/code-review` found a regression: the new `team` filter matched team names, while `characters_list` sent team ids, so a team-opened list was empty and its test only checked the query. It also found 5 more issues. Fix round `d7b06b45`:
  - `team` now means the team id (`teamIdOf`, CONTRACT.md), with a new list test that checks the rows;
  - the linked query is trimmed;
  - one shared empty-message helper;
  - the drift test is strict again (route templates compared).

  Optional items 3 and 4 went to P-125.
- TL checks: no deleted or skipped tests, and no modified test lost assertions. The 3 `characters_list` goldens were regenerated for the new search icon, with before and after images in evidence.
- The TL merged `--no-ff`. On the merge result: `check` passed, 246/246 tests, lint clean, `mc_arch_check` OK, sim app built, format gate passed, and a 20-run uncached flake check over 18 targets was clean.
