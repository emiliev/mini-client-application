# Library contract (`mc_fixtures_library`)

Our own domain-first contract (F-0003): the signed-in user's reading lists, for the library feature (the reading-list editor). It claims no compatibility with any real API. Content is invented.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. Lists live in the backend's store, per user, so every write persists across requests until `reset()`, which restores the seeded lists and restarts the id counter. The domain owns no comics: it reads `mc_fixtures_comics` through its public API, so an item id is a comic id on `GET /v1/comics/:id`, and its title and thumbnail are what that endpoint serves (`title`, `cover`).

## Auth

Every route needs `Authorization: Bearer <access token>`, checked with `mc_fixtures_identity`'s own `userForAuthorization` (the same shape rule as `GET /v1/me`; there is no second token scheme). A missing, malformed or expired token, a refresh token used as a bearer, a token of an unknown user or a scheme other than `Bearer` is `401` `unauthenticated`. Auth is checked first: before the list id, before the body. A test can mint a token without signing in: `mintAccessToken('u-100', 1)`.

A list belongs to the user who created it. Another user's list, and an id that does not exist, are both `404` `list_not_found`, so ids are not leaked (never `403`).

## Routes

| Route | Purpose |
|---|---|
| `GET /v1/me/lists` | The user's lists |
| `GET /v1/me/lists/:id` | One list with its items |
| `POST /v1/me/lists` | Create a list |
| `PUT /v1/me/lists/:id` | Update the name, description and visibility |
| `PUT /v1/me/lists/:id/items` | Replace the items and their order |
| `DELETE /v1/me/lists/:id` | Delete a list |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `GET /v1/me/lists`

`200` `{"lists": [<list>, ...]}` with the user's lists, **most recently updated first** (ties by id), where a list is:

```json
{"id": "l-1", "name": "Spider-Verse Starter", "description": "Where to begin.", "visibility": "public", "itemCount": 3, "updatedAt": "2025-12-30T00:00:00.000Z"}
```

`description` is always a string (`""` when there is none).

### `GET /v1/me/lists/:id`

`200` the list above plus `items`: the comics in the stored order, each `{"id": 500000, "title": "...", "thumbnail": {"path": "mock-asset://characters/003", "variant": "portrait_large"}}`. `404` `list_not_found`.

### `POST /v1/me/lists`

Body `{"name": string, "description"?: string, "visibility": "private"|"public", "comicIds": [int]}`; `comicIds` may be empty. `201` with the new list in the `GET /v1/me/lists/:id` shape (so `id` is in the body). Ids are `l-<n>` from one counter per backend (seeded lists take `l-1` to `l-4`, so the first new list is `l-5` in the default set and `l-1` in the empty one). The name is stored trimmed.

### `PUT /v1/me/lists/:id`

Body `{"name": string, "description"?: string, "visibility": ...}`. `200` with the list in the detail shape. The items are untouched. An absent or `null` description clears it. `404` `list_not_found` comes before any `400`.

### `PUT /v1/me/lists/:id/items`

Body `{"comicIds": [int]}`: the items become exactly this list, in this order (it may add, drop and reorder; an empty list clears them). `200` with the detail shape. `404` before `400`.

### `DELETE /v1/me/lists/:id`

`204` with no body. A second delete is `404`.

Every write sets `updatedAt` to the fixed clock plus one second per write on this backend (deterministic, and later edits sort first).

## Validation

All failures are `400` with `{"error": {"code", "message", "parameter", ...}}`. Checks run in the order below and the first failure is the answer; a rejected write changes nothing and takes no id.

| Order | `error.code` | Rule | Extra fields |
|---|---|---|---|
| 0 | `invalid_body` | The body is not a JSON object | |
| 1 | `invalid_name` | `name` missing, not a string, or not 1 to 60 characters after trimming | `parameter: "name"` |
| 2 | `invalid_description` | `description` present, not null, and not a string of at most 280 characters (not trimmed) | `parameter: "description"` |
| 3 | `invalid_visibility` | `visibility` is not exactly `private` or `public` | `parameter: "visibility"` |
| 4 | `invalid_body` | `comicIds` missing, not a list, or holds a non-integer | `parameter: "comicIds"` |
| 5 | `too_many_comics` | More than 100 ids | `parameter`, `maxItems: 100` |
| 6 | `duplicate_comic` | An id appears twice (the first repeated one is named) | `parameter`, `comicId` |
| 7 | `unknown_comic` | An id is not a comic of `mc_fixtures_comics` (the first unknown one is named) | `parameter`, `comicId` |

Lengths count characters (runes), not UTF-16 units. `POST` checks 0 to 7, `PUT /v1/me/lists/:id` checks 0 to 3, `PUT .../items` checks 0, 4 to 7.

### Other errors

| Status | `error.code` | When |
|---|---|---|
| 401 | `unauthenticated` | See Auth |
| 404 | `list_not_found` | Unknown or foreign list id (`id` in the body) |
| 404 | `not_found` | No mock route (the body names the path) |
| 500 | `handler_error` | A handler threw |
| any | `injected_failure` | A `FailureRule` of kind `http(status)`; also the body of the `server_error` set |

## Test-facing facts (default set, seed 42)

| Fact | Value |
|---|---|
| `u-100` (`reader@mini-client.test`) | `l-1` "Spider-Verse Starter" (public, 3 items), `l-2` "Weekend Reads" (private, 2 items, no description), `l-3` "Someday" (private, no items); listed in that order |
| `u-101` (`collector@mini-client.test`) | `l-4` "Collector Shortlist" (public, 3 items) |
| Seeded `updatedAt` | the fixed clock `2026-01-01T00:00Z` minus 2, 10, 30 and 5 days for `l-1` to `l-4` |
| Seeded items | positions 0, 40, 80 (`l-1`), 5, 15 (`l-2`) and 100, 200, 300 (`l-4`) in `mc_fixtures_comics` title order |
| Independent of the seed | list ids, names, titles and ids of the items (thumbnails follow the comics domain) |

## Scenarios

| Name | Effect |
|---|---|
| `library.empty` | The routes keep validating and authenticating, but start with no lists for either user (its own state, so it is empty even after the default set was used). Items resolve against the seed-42 comics |
| `library.server_error` | Every route fails with `500` (`injected_failure`) |

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `libraryFixtureSets`. A test registers them once (`libraryFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario. Each set serves all six routes. The set and the scenario of the same name answer the same bodies. A set is meant to be served with the comics set that its items link to, and with the identity set that issues the token.

| Set | Cast | Test-facing facts |
|---|---|---|
| `library.default` | `LibraryMockDomain` | See the table above |
| `library.empty` | `EmptyLibraryDomain` | no lists for anyone; first created id is `l-1`; auth and validation unchanged; no scenarios |
| `library.server_error` | `FailingLibraryDomain` | all six routes answer `500` with `error.code` `injected_failure`, the same body as the scenario (whatever the auth); no scenarios |

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `requestBody`, `status`, `body`), run on a fresh default backend. A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_library/tool/update_snapshots.dart`, review it, and update this file.
