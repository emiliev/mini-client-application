# T-0071: `characters_search`, name-prefix search over characters with facets and history (F003)

| Field | Value |
|---|---|
| Status | In Progress |
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
