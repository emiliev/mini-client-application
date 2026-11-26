# T-0047: `mc_fixtures_library`, the reading-lists mock domain (P1-09 subset, U44)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (fixtures; ADR-0011) |
| Branch | `fleet/T-0047-fixtures-library` |
| Created | 2026-11-26 |
| Depends on | T-0038 (`mc_fixtures_comics`), T-0039 (`mc_fixtures_identity`, bearer tokens), T-0043 (fixture conventions) |
| Related | plan 01 U44, P1-09, F066 (FW exemplar `library_reading_list_editor`, P1-20); ADR-0005; the identity and comics `CONTRACT.md` files |

## Goal
The backend for the FW exemplar (P1-20), where a user creates or edits a reading list in a wizard and reorders its items. Reading lists belong to the signed-in user, so every route needs a valid bearer from `mc_fixtures_identity`.

## Scope
- **In:**
  - `utility/mc_fixtures_library` (UM, pure Dart). It reads comics through `mc_fixtures_comics`' public API and validates tokens the same way `mc_fixtures_identity` does: no second token scheme.
  - Routes:
    - `GET /v1/me/lists`: the user's lists (`id`, `name`, `description`, `visibility`, `itemCount`, `updatedAt`).
    - `GET /v1/me/lists/{id}`: one list with its items, as comic summaries (`id`, `title`, `thumbnail`) in order.
    - `POST /v1/me/lists`: create from `{name, description?, visibility, comicIds[]}`; returns 201 with the new id.
    - `PUT /v1/me/lists/{id}`: update the name, description and visibility.
    - `PUT /v1/me/lists/{id}/items`: replace the order with `{comicIds[]}`.
    - `DELETE /v1/me/lists/{id}`.
  - Validation, all returning 400 with a typed `error.code`:
    - name 1–60 characters after trimming;
    - description ≤ 280 characters;
    - visibility `private` or `public`;
    - `comicIds` known, with no duplicates, at most 100.
  - Auth: 401 without a valid bearer. A list owned by another user returns 404, not 403, so ids aren't leaked.
  - Writes persist until `reset()` and are kept per user.
  - The `default` set seeds two fixture users with 0–3 lists each. There are also `empty` and `server_error` sets and scenarios, with one identical body for each. The package has a `CONTRACT.md`.
- **Out:** collections, history, downloads and favourites. Favourites already live in identity.

## Acceptance criteria
- **T-0047-AC1:** Determinism, as in P1-06 AC1: the same requests produce byte-identical responses for seed 42.
- **T-0047-AC2:** CRUD:
  - Create returns 201 with an id, and the list then appears in `GET /v1/me/lists`.
  - Update and reorder persist.
  - Delete removes the list.
  - Every write persists until `reset()`.
  - User A's lists are invisible to user B (404).
  - Reordering keeps exactly the submitted order.
- **T-0047-AC3:** Every validation rule from the scope returns 400 with its typed code. Pin each rule: removing it must turn a test red. Auth: no bearer or an expired bearer returns 401.
- **T-0047-AC4:** The contract snapshots match. Every item id resolves on `GET /v1/comics/{id}`, and every thumbnail resolves to a bundled asset.
- **T-0047-AC5:** The package is pure Dart (closure check with a negative control), registered, ≥ 90 % covered, and passes the fixtures check. Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format. Globs use `MC_GENERATED_DART`.

## Log
- 2026-11-26: Created and dispatched (TL).
- 2026-11-26: Engineer (Sonnet). `utility/mc_fixtures_library` built and registered. One public hook added to `mc_fixtures_identity`: it now exports `userForAuthorization` (already the check behind `GET /v1/me`), with a test (`T-0047-AC3 userForAuthorization is the check GET /v1/me applies`). No second token scheme. Merged `origin/main` (docs only, no lock change).
- 2026-11-26: Decisions inside the scope (all in `CONTRACT.md`): typed codes `invalid_name`, `invalid_description`, `invalid_visibility`, `invalid_body`, `too_many_comics`, `duplicate_comic`, `unknown_comic`; `list_not_found` for unknown and foreign ids; checks run auth, then 404, then body (name, description, visibility, comicIds); `server_error` set and scenario share the `injected_failure` body (T-0043 convention); `library.empty` scenario keeps its own state, so it is empty even after the default set was used; `POST` returns the full detail body (with `id`); `updatedAt` of a write is the fixed clock plus one second per write.

## Outcome
`utility/mc_fixtures_library` (archetype UM, pure Dart) is registered in the workspace. It reads comics through `ComicUniverse` (`mc_fixtures_comics`) and validates bearers with `userForAuthorization` (`mc_fixtures_identity`). Six routes, per-user lists kept in the backend store until `reset()`, two seeded users (`u-100`: 3 lists, `u-101`: 1 list), sets `library.default/empty/server_error` and scenarios `library.empty/server_error`. See `CONTRACT.md`.

| AC | Evidence |
|---|---|
| AC1 | `library_test.dart`: `T-0047-AC1` (a 6-request sequence with writes is byte-identical on two backends; replay after `reset()` is byte-identical) |
| AC2 | `library_test.dart`: `T-0047-AC2` (seed, create 201 with id and appears in the list, two creates get distinct ids, items in order with title and thumbnail, update persists and keeps items, absent description clears, reorder keeps exactly the submitted order incl. add/drop/empty, delete 204 then 404, recency order, persistence across Dio instances and `reset()` restoring the seed and the id counter, user B gets 404 on every route for A's list, unknown and foreign ids look the same, each user's creations are private) |
| AC3 | `validation_test.dart` and `library_test.dart`: `T-0047-AC3` (each rule on every route that carries it: name empty/blank/missing/non-string/61/trim/60/rune count, description 281/280/null/absent/non-string/rune count, visibility, comicIds shape/101/100/duplicates/unknown/empty, check order, 404 before 400, rejected writes change nothing and take no id; 401 without bearer, expired, refresh-as-bearer, unknown user, wrong scheme on all six routes plus invalid body and unknown id) and `identity_test.dart` (`userForAuthorization`) |
| AC4 | `provider_contract_test.dart` and `fixture_sets_test.dart`: `T-0047-AC4` (19 snapshots, manifest, scenarios, CONTRACT.md in step, every item id resolves on `GET /v1/comics/{id}` with the same title and cover for seeds 42 and 7, every thumbnail resolves to an existing asset, resolver negative control; sets: default/empty/server_error, set and scenario bodies identical, empty scenario empty after default use) |
| AC5 | `tool/checks/T-0047-AC5_gates.sh`: pure closure (1358 targets; positive control `mc_fixtures_media`, negative control: the media package added to the library's BUILD shows the markers), registration, fixtures check (positive and negative controls), uncached library tests 4/4, `test //...` 127/127 after the final merge, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, coverage 98.5 % (194/197). Report: `documents/evidence/T-0047/engineer/AC5_gates.md` |

Mutations: `documents/evidence/T-0047/engineer/mutations.sh` (`MC_TASK=T-0047 MC_ROLE=engineer`, refuses a dirty package), log `mutations.log`: **58/58 killed**, none survived, none broke the build. Every validation rule and boundary, the auth check (header, status, code), ownership (find, list, create), each write, ordering, id reuse, the set/scenario bodies and the empty-state isolation are pinned. Two survivors in the first pass (create sorting its ids, id reuse) led to stronger tests; the mutations that failed `dart format` or the analyzer were rewritten to be clean.

Test integrity: no tests deleted, skipped or weakened; no `// ignore:`. Globs use `MC_GENERATED_DART`.

## Review round (2026-11-26, Engineer)
1. `library.empty` scenario no longer fixed to seed 42: handlers resolve the comics universe from `context.seed` (cached per seed). Test: `T-0047-AC4 seed 42/7: the library.empty scenario answers what the empty set answers, with the comics endpoint's titles and covers`.
2. No `ComicUniverse` per `scenarios` access (same change).
3. Empty state has its own id space (`l-1001`...). Test: `T-0047-AC4 switching library.empty off never aliases a created id onto a seeded list`. Documented.
4. Coupling to the library's own `ComicUniverse(seed)` documented in `CONTRACT.md` (incl. `comics.empty`, `SyntheticComicsDomain`).
5. Order-0 `invalid_body` carries `parameter: "body"`; snapshot updated; asserted in `T-0047-AC3 a body that is not an object is invalid_body`.
6. Gates script: backups in the scratch dir, restore trap installed before the edits, restores verified with `cmp` against `HEAD`; "discovery" slip fixed in the `mutations.sh` header.
Mutations R1 to R3 and S7 added (58/58 killed).
