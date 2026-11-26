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
