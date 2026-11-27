# T-0067: `characters_details` feature: the character profile behind "See full profile" (F002)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-27 `21b57873`; review-first and merge gates per ADR-0015) |
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
- 2026-11-27: Engineer started from `origin/main` `16b26bf`. Copied `comics_details` (favourite bloc, guards, steps) and rewrote its domain, page and tests for the profile.
- 2026-11-27: Fixture extension in `mc_fixtures_characters` (aliases, stats; drawn after every served field, so nothing moved), with tests and `CONTRACT.md`.
- 2026-11-27: Wiring in `universe_wiring`: the real `CharacterDetailsFlow`, `CharacterDetailsNavigatorImpl` (`openComic` through `AppLocations.comic`, `requestSignIn` through `requestFixtureSignIn`, the hook every wiring uses today), the placeholder flow deleted, tests rewritten over `McTestContainer`.
- 2026-11-27: Other tests that named the placeholder now name the real profile: `mini_client` tests and journeys, the universe sandbox tests and journeys. No test was deleted, skipped or weakened; the placeholder assertions were replaced by assertions on the real name, comics and Back.
- 2026-11-27: E2E on `mc-T-0067-engineer-*` (deleted each time): the first two runs found two bugs of the new journey test (a missing import; waiting for a header that a scrolled list does not build, then a wrong Back target: the preview, not the grid). Fixed in the test; the app was right. Final run 3/3 PASS.
- 2026-11-27: Review round (`/code-review`, 3 important findings in the favourite bloc, fixed in **both** `character_favourite_bloc` and `comic_favourite_bloc`):
  1. An announcement that arrives while a tap is in flight sets `_stale`; the tap's ending reads the flag again.
  2. Every read takes a number from `_loadSeq`; only the newest writes its answer, and a tap also bumps it, so a read that predates a write cannot undo it.
  3. A background refresh (same session, a value already shown) keeps that value and emits no `loading`; `loading` is for the first read and a new session.
  Tests (each fails on the old bloc; checked for `characters_details`): `bloc_guards_test` "two reads that finish out of order ...", "a tap during a background read is not overwritten ...", "a background refresh never emits loading"; BDD "An announcement that arrives during a write is applied when the write settles" and "A refresh caused by an announcement keeps the toggle as it was, enabled", in both features (`T-0067-AC3`, `T-0041-AC6`, `T-0050-AC2`). Nits: both old test IDs are back in the renamed tests (`T-0033-AC4 T-0067-AC5 ...`, `T-0041-AC8 T-0067-AC3 ...`); empty origin and bio rows are left out (new `characters_details_synthetic.feature`); `_settleRealIo` now fails when the sheet never closes.
- 2026-11-27: Gates run on the branch, see AC6. Finding: [F-0067](../findings/F-0067-characters-details.md).

## Outcome
**Handed off** for `/code-review` and the TL's merge gates on `fleet/T-0067-characters-details`. Finding: [F-0067](../findings/F-0067-characters-details.md). Evidence: [`documents/evidence/T-0067/engineer/`](../evidence/T-0067/engineer/) (and `engineer-sandbox/`).

### What was built
- **`feature/characters/characters_details`** (SC, copied from `comics_details`):
  - `CharacterDetailsFlow(navigator, characterId)` with one page, the screen `character_details`; `CharacterDetailsNavigator.openComic(ComicId)` and `requestSignIn()`.
  - `CharacterDetailsBloc`: the character and its comics (`GET /v1/comics?characterId=`) in parallel; `notFound`, `failure` with Retry; the open guard keyed by the comic.
  - `CharacterFavouriteBloc`: `comics_details`' favourite with `/v1/me/favourites/character/:id`, the shown-epoch guard, `authPinned`, `DataChanged('favourites')`, and `character_favourited` (`id`) for a saved favourite only.
  - Page: header (portrait, name, "Also known as ..."), favourite, bio, power stats as an `McBarChart`, the comics row, the details (origin, team, first appearance, powers).
  - Strings in en, de, en_XA (30 keys).
- **`utility/mc_fixtures_characters`**: the detail gains `aliases` (0 to 2) and `stats` (six, 1 to 100), drawn after every served field; `CONTRACT.md`, the `detail` snapshot and 5 tests.
- **`app/wiring/universe_wiring`**: the route builds the real flow; the placeholder is gone.

### AC → evidence
Every test below was grepped at the handoff commit.

| AC | Tests and evidence |
|---|---|
| AC1 | BDD `characters_details.feature`: "The profile shows the header, the bio, the stats, the comics and the favourite"; "The details name the origin, the team, the first appearance and the powers"; "A character with no aliases shows no aliases line"; "A character no comic features says so instead of showing a row". Contract tests (`T-0067-AC1`): the DTO round trip, the mapper, the stats mapping (order, 1 and 100, a missing / 0 / 101 / -5 stat, an unknown variant), the comics page in title order. Fixture tests `T-0067-AC1` in `mc_fixtures_characters:characters_test`. `flow_scope_test` "T-0067-AC1 the flow's container resolves every registration". |
| AC2 | BDD: "A failed character explains the problem and retries" (4 failures: server error, timeout, offline, malformed); "Failed comics fail the page, and Retry loads both again" (2 character requests, 4 comics requests); "A double Retry sends one request"; "An unknown character shows that it was not found"; "An unknown character is not found even when the comics fail". |
| AC3 | BDD: "Tapping a comic hands it over to the app exactly once"; the double tap, 499 ms, 501 ms and 450 ms scenarios (`openComic` counts). `characters_details_favourite.feature` (25 scenarios): signed out asks to sign in once; signed in toggles at once and rolls back; persists (`GET`/`PUT`/`DELETE` with the bearer of the user); a user switch right before a write sends nothing under the other user's bearer (`signs in just before the app sends`, both `PUT` and `DELETE`); sign-in, sign-out and switch elsewhere; `character_favourited` tracked once, never for a removal, a failed write or a backed-out sign-in. `bloc_guards_test` (3): the stale tap, the analytics count, the open guard. `universe_wiring:routes_test` "T-0067-AC3 the profile's openComic pushes the comic location, and Back returns to the profile", the `requestSignIn` tests (sheet, Not now, already signed in), "the route targets build each flow with the wiring navigator". `mini_client:analytics_screens_test` "T-0067-AC3 in the app, a favourite saved from a profile tracks character_favourited with its id". |
| AC4 | BDD `@l10n`: German sections and labels; "In German at <scale>x nothing overflows on any state" (1 and 2); the pseudo-locale at 1 and 2 for every section, the comics-less character, not found and failed, and German not found and failed at 1 and 2; "The stats chart reads each stat in English for a screen reader" and the German one (`the stats chart reads {...} then {...}`: summary, then "Strength: 93" ... in traversal order). `tool/l10n_check` "T-0067-AC4 the gate checks the characters_details ARB set". |
| AC5 | E2E on a fresh `mc-T-0067-engineer-*` simulator (deleted): [summary](../evidence/T-0067/engineer/e2e-summary.md), 3/3 PASS. `characters_journey_test`: home → Characters → preview → See full profile → the character → a comic → Back → Back (screenshots 01 to 08). `character_details_deeplink_test`: the cold link `miniclient://app/characters/100366`, Back to the list, Back to home (55, 55b, 55c). `comics_journey_test`: a cast member opens the profile (17). The universe sandbox's two link tests: [summary](../evidence/T-0067/engineer-sandbox/e2e-summary.md), 2/2 PASS. |
| AC6 | See the gates below; [`runs_per_test_50.md`](../evidence/T-0067/engineer/runs_per_test_50.md); `characters_details:architecture_test` ("T-0067-AC6": the barrel, no Flutter in generator-read files). |

### Gates (run on the branch at the handoff commit)
- `test --lockfile_mode=error //...`: 228 of 228 pass (also after the review round).
- `build --config=lint //...`: clean.
- `mc_arch_check`: OK. `rules_fork.sh check`: OK. `l10n_check`: OK. `tool/checks/lib/format_gate.sh`: 0 changed.
- `T-0042-AC4_safety.sh` after `tool/ide_sync`: [report](../evidence/T-0067/engineer/T-0042-AC4_safety.md).
- 50-run flake check (`--runs_per_test=50 --nocache_test_results`) on `characters_details` (bdd, bloc_guards, contract, flow_scope), `universe_wiring:routes_test` and four `mini_client` route and analytics tests: 0 failures in 50 runs each.

### Changes outside the feature (TL, please confirm)
- `utility/mc_fixtures_characters`: `aliases` and `stats` on the detail (new fields only), the exported `statNames`, `CONTRACT.md`, the `detail` snapshot, 5 tests.
- `app/wiring/universe_wiring`: its `UniverseNavigatorsDIInitializer` now also needs `SessionReader` and `AuthApi` (for the sign-in hook), so its tests boot over `McTestContainer`; the placeholder flow is deleted.
- `tool/l10n_check` (BUILD data and one test), the workspace `pubspec.yaml` (new member).
- Tests that named the placeholder: `mini_client` (`comic_route_test`, `search_route_test`, `deep_link_back_stack_test`, `analytics_screens_test` gains 2 tests, 3 integration journeys), the universe sandbox (`fake_targets`, links test, 2 integration tests). All of them assert the real profile now.

### Not done / follow-ups
- After a failed read, a tap still assumes "not a favourite" and writes without re-reading the flag (both favourite blocs). Left for a later round: it needs a new state transition and a scenario.
- The preview in `characters_list` does not show the aliases the detail now has.
- `appearances` (comics, series, events) is served and parsed but not shown: its counts are random and would contradict the comics row.
- One rule for singular or plural class names in the SC brick (F-0067 section 1).
- T-0066 replaces the sign-in sheet: `CharacterDetailsNavigatorImpl.requestSignIn` calls `requestFixtureSignIn`, exactly as the other five wirings do, so its merge switches them together.

## Merge (TL)
- 2026-11-27: `/code-review` found 3 important favourite-bloc issues (a missed announcement while busy, out-of-order reads, refresh flicker), all shared with `comics_details`, plus the AC-ID traceability nit. Fix round `721eab3e` fixed them in **both** blocs and restored both old IDs in the renamed tests.
- TL checks: no deleted or skipped tests; the 13 "removed" assertions are re-indented, with equal counts added per file.
- The TL merged `--no-ff`. On the merge result: `check` passed, 228/228 tests, lint clean, `mc_arch_check` OK, sim app built, format gate and provenance passed, and a 20-run uncached flake check over 12 targets was clean.
- Follow-up: P-121.
