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
