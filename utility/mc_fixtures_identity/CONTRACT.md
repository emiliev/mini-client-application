# Identity contract (`mc_fixtures_identity`)

Our own domain-first contract (F-0003): a mock identity provider with sign-in, token refresh, sign-out, the current user and per-user favourites. It claims no compatibility with any real identity service. Users and tokens are invented.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. State (issued-token counter, used refresh tokens, favourites) lives in the backend's store, so writes persist across requests until `reset()`.

## Users

| `id` | Email | Password | Name | Favourites at start (`identity.default`) |
|---|---|---|---|---|
| `u-100` | `reader@mini-client.test` | `marvelous` | Rhea Reader | `character/100000`, `character/100001` |
| `u-101` | `collector@mini-client.test` | `vault-7` | Cole Collector | none |

The email match is case-insensitive and ignores surrounding blanks.

## Tokens

Opaque strings with a fixed shape, so a test can mint one without signing in:

| Token | Shape | Valid when |
|---|---|---|
| Access | `mc-access-<userId>-<n>` | the user exists and `n` is a number. `mc-access-<userId>-expired` is the expired form |
| Refresh | `mc-refresh-<userId>-<n>` | the user exists, `n` is a number and the token was not used or signed out before |

`n` comes from one counter per backend (1, 2, 3, ...), so a request sequence always yields the same tokens. The counter skips a number whose refresh token the backend already revoked: the backend starts empty on every launch, so a session saved by an earlier run can hold `mc-refresh-u-100-1` while a fresh counter would mint that same string again (the first refresh with it therefore returns number 2). `expiresIn` is always `900` (seconds); the mock does not run a clock, so "expired" is only the `expired` form. A token that survives an app restart is still accepted: the check looks at the shape, not at remembered state (the backend starts empty on each launch).

Refresh tokens **rotate**: a refresh token works once. A second refresh with the same token is `401`. This is deliberate, so a client that refreshes twice in parallel fails visibly.

`mc_fixtures_identity` exports `mintAccessToken(userId, n)`, `mintRefreshToken(userId, n)` and `expiredAccessToken(userId)`.

## Routes

| Route | Purpose |
|---|---|
| `POST /v1/auth/sign-in` | Sign in with email and password |
| `POST /v1/auth/refresh` | Trade a refresh token for a new pair |
| `POST /v1/auth/sign-out` | Revoke a refresh token |
| `GET /v1/me` | The signed-in user |
| `GET /v1/me/favourites/:kind/:id` | Whether this item is a favourite |
| `PUT /v1/me/favourites/:kind/:id` | Mark it as a favourite |
| `DELETE /v1/me/favourites/:kind/:id` | Remove it |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `POST /v1/auth/sign-in`

Body `{"email": string, "password": string}`. Response `200`:

```json
{
  "user": {"id": "u-100", "email": "reader@mini-client.test", "displayName": "Rhea Reader"},
  "accessToken": "mc-access-u-100-1", "refreshToken": "mc-refresh-u-100-1",
  "tokenType": "Bearer", "expiresIn": 900
}
```

A wrong password or an unknown email gives `401` with `{"error": {"code": "invalid_credentials", ...}}` and no tokens. A body that is not that shape gives `400` `invalid_body`.

### `POST /v1/auth/refresh`

Body `{"refreshToken": string}`. Response `200` is `{accessToken, refreshToken, tokenType, expiresIn}` (no `user`). An unknown, malformed, used or signed-out token gives `401` `invalid_refresh_token`; a body without `refreshToken` gives `400` `invalid_body`.

### `POST /v1/auth/sign-out`

Optional body `{"refreshToken": string}`, which is revoked. Needs no bearer, so a client with an expired access token can still sign out. Always `204` with no body.

### `GET /v1/me`

Needs `Authorization: Bearer <access token>`. Response `200`: `{id, email, displayName, favouriteCount}`. A missing, malformed or expired token gives `401` `unauthenticated`.

### `/v1/me/favourites/:kind/:id`

`kind` is `character`, `comic`, `event` or `series`; anything else is `400` `invalid_parameter` with `parameter: "kind"`. `id` is any string. All three methods need the bearer (`401` `unauthenticated` otherwise).

| Method | Result |
|---|---|
| `GET` | `200` `{kind, id, favourite: true}`, or `404` `not_favourite` |
| `PUT` | `200` `{kind, id, favourite: true}`; idempotent |
| `DELETE` | `200` `{kind, id, favourite: false}`; idempotent |

Favourites are per user and kept until `reset()`, which also restores the seeded ones.

### Errors from the engine

| Status | `error.code` | When |
|---|---|---|
| 404 | `not_found` | No mock route (the body names the path) |
| 500 | `handler_error` | A handler threw |
| any | `injected_failure` | A `FailureRule` of kind `http(status)` |

## Scenarios

| Name | Effect |
|---|---|
| `identity.expired_token` | `POST /v1/auth/sign-in` hands out `mc-access-<userId>-expired` with a good refresh token, so the first authenticated request gets `401` and one refresh fixes it |
| `identity.server_error` | Every route of the table above fails with `500` |

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `identityFixtureSets`.

| Set | Contents |
|---|---|
| `identity.default` | The seven routes, the users above, seeded favourites, and the two scenarios |
| `identity.empty` | The same routes with no seeded favourites (`favouriteCount` 0 for both users); no scenarios |
| `identity.server_error` | The same routes, each answering `500` `server_error`; no scenarios |

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `status`, `body`). A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_identity/tool/update_snapshots.dart`, review it, and update this file.
