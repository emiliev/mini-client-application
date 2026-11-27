# T-0067: `characters_details` feature: the character profile behind "See full profile" (F002)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verification | ADR-0015: `/code-review`, one fix round, TL merge gates. No Verifier. |
| Branch | `fleet/T-0067-characters-details` |
| Created | 2026-11-27 |
| Depends on | T-0032/T-0034 (`characters_list`), T-0041 (`comics_details`, the SC exemplar to copy), T-0040 (DS navigation), T-0059 (`mc_ds_charts`), T-0056 (analytics, ADR-0012) |
| Related | plan 01 F002 ("Character profile: header, bio, stats, favourite toggle, links out"), the SC archetype; `mc_fixtures_characters` `GET /v1/characters/:id`; `universe_wiring` `CharacterDetailsPlaceholderFlow` |

## Goal
Today "See full profile" in the characters preview, and the link `miniclient://app/characters/<id>`, open a placeholder. Replace it with a real character profile, built in the shape of the SC exemplar `comics_details`.

## Scope
- **In: `feature/characters/characters_details`, a copy of `comics_details`' shapes.**
  - **Flow and navigator.** `CharacterDetailsFlow(characterId)` with one page. `CharacterDetailsNavigator` has two outbound methods:
    - `openComic(ComicId)` for the character's comic appearances;
    - `requestSignIn()` for the favourite.
  - **API and repository.** Use `GET /v1/characters/:id` as served. If the fixture lacks fields the page needs (bio, stats, appearances), extend `mc_fixtures_characters` with deterministic data and tests. Keep `characters_list` green.
  - **Page.**
    - A header with portrait, name and aliases.
    - Bio.
    - A stats section drawn as an `McBarChart` from `mc_ds_charts`, for example the power stats.
    - A "Comics" horizontal list that opens `comics_details`.
    - Teams, if the data has them.
    - A favourite toggle that works exactly like `comics_details`' favourite: sign-in when signed out, `authPinned` writes, the shown-epoch guard, and `DataChanged('favourites')`. Use `/v1/me/favourites/character/:id`, which identity already supports for any kind.
  - **Analytics (ADR-0012).** The screen is named `character_details`. Track `character_favourited`.
  - **Tests and copy.**
    - l10n in en and de.
    - BDD, contract tests, and unit tests for pure logic.
    - **No goldens** (ADR-0015).
- **In: `universe_wiring`.**
  - The `CharacterDetailsRoute` builds the real flow. Delete the placeholder flow and update its tests; the route keeps the same URL.
  - Add the navigator implementation: the comic through `AppLocations.comic`, sign-in as the other wirings do it today.
  - **T-0066 is replacing the sign-in path in parallel.** Use the same `requestSignIn` hook the other wirings use, so the T-0066 merge can switch all of them at once.
- **Out:** powers (F004) and timeline (F009) pages, and team pages.

## Acceptance criteria
- **T-0067-AC1:** Given `characters.default`, when I open a character, then I see the header, the bio, the stats chart, the comics and the favourite. BDD.
- **T-0067-AC2:**
  - Given `server_error`, an error with Retry shows, and Retry recovers.
  - An unknown id shows the not-found state.
  - BDD.
- **T-0067-AC3:**
  - Tapping a comic calls `openComic` exactly once. The double-tap guard works as in `comics_details`.
  - The favourite works: signed out, it asks to sign in; signed in, it toggles and persists. A user switch during a write sends nothing under the other user's bearer. Copy the `comics_details` guard tests.
  - The wiring test pushes the comic location.
- **T-0067-AC4:**
  - `de` and `en_XA` at 1× and 2× text size, with no overflow.
  - The chart's semantics read the stats.
- **T-0067-AC5:** E2E on your own simulator: home → Characters → preview → See full profile → the character → a comic → Back → Back. Also the cold link `miniclient://app/characters/<id>`, where Back walks the list to home (T-0049). Take screenshots.
- **T-0067-AC6:** Gates:
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, the format gate, `l10n_check`, and `T-0042-AC4_safety.sh` after `tool/ide_sync`;
  - the 50-run flake check on targets that touch the session or races;
  - every cited test exists.

## Log
- 2026-11-27: Created and dispatched (TL). PO chose the hybrid: hand-built features in parallel with the generator.
