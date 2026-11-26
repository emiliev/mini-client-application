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
