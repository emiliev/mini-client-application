# Platform contract (`mc_fixtures_platform`, flags slice)

Our own domain-first contract (F-0003): the remote feature flags and experiments a client reads at start and whenever the session changes. It claims no compatibility with any real flag service. Flag keys and values are invented. The package is the platform domain's first slice (U49); remote config, the notifications inbox, system status and insights come in later tasks and will add routes here.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. The body does not depend on the backend seed, and nothing is stored: every call answers the same until the user changes (seed 42 and seed 7 give the same bytes).

## Auth

Auth is **optional**. `Authorization: Bearer <access token>` is read with `mc_fixtures_identity`'s own `userForAuthorization` (the same shape rule as `GET /v1/me`; there is no second token scheme). A valid token adds that user's targeting. A missing, malformed or expired token, a refresh token used as a bearer, a token of an unknown user or a scheme other than `Bearer` is **anonymous**: `200` with the anonymous flags, never `401`.

## Routes

| Route | Purpose |
|---|---|
| `GET /v1/flags` | The flags and experiments for the caller (anonymous or one seeded user) |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `GET /v1/flags`

`200`
```json
{
  "flags": {"catalogue.page_size": 20, "...": "..."},
  "experiments": [
    {"key": "store_home_layout", "variants": [{"name": "control", "weight": 5000}, {"name": "compact", "weight": 3000}, {"name": "rich", "weight": 2000}]}
  ]
}
```

- `flags` maps a flag key to a JSON value (bool, int, string). A client ignores keys it has no flag for, and treats a value of the wrong type as absent.
- `experiments` lists each experiment's variants with a non-negative integer `weight`. Weights are relative: a client scales the cumulative weight to 10000 buckets. A zero weight is never assigned.

## Flags of the default set (seed-independent)

| Key | Type | Anonymous | `u-100` | `u-101` |
|---|---|---|---|---|
| `catalogue.page_size` | int | `20` | `20` | `40` |
| `dev.diagnostics` | bool | `false` | `false` | `false` |
| `search.layout` | string | `"grid"` | `"list"` | `"grid"` |
| `settings.accent` | string | `"red"` | `"red"` | `"red"` |
| `store.promo_banner` | bool | `false` | `true` | `false` |

Targeting is by user id only; every key a user is not listed for is the anonymous value. `u-100` therefore differs from anonymous on two flags, `u-101` on one.

## Experiments of the default set

| Key | Variants (weights) |
|---|---|
| `store_home_layout` | `control` 5000, `compact` 3000, `rich` 2000 |
| `trivia_hint` | `control` 10000, `hint` 0 (the zero weight never gets a subject) |

Experiments are not targeted: every caller gets the same weights.

## Errors

| Status | `error.code` | When |
|---|---|---|
| `500` | `injected_failure` | A `FailureRule` of kind `http(status)`; also the body of the `server_error` set |

Nothing else fails: there is no `401`, `404` or `400` on this route.

## Scenarios

Switched on with `MockBackend.useScenario(name)` or `backend.scenario` in the app config.

| Name | Effect |
|---|---|
| `platform.empty` | `{"flags": {}, "experiments": []}` for everyone |
| `platform.flags_malformed` | `200` with well-formed JSON whose values have the wrong type, for everyone (below) |
| `platform.server_error` | `GET /v1/flags` fails with `500` (`injected_failure`) |

**`platform.flags_malformed`** serves the anonymous flags except: `catalogue.page_size` is the string `"twenty"` (an int is expected), `store.promo_banner` is the int `1` (a bool is expected) and `search.layout` is `"carousel"` (no such enum name). In `store_home_layout`, the `compact` variant has the string weight `"heavy"`. `trivia_hint` is valid. It is the way to test a client's wrong-type fallback.

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `platformFixtureSets`. A test registers them once (`platformFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario. Each set serves `GET /v1/flags`. The set and the scenario of the same name (all but `platform.default`) answer the same status and body.

| Set | Cast | Test-facing facts |
|---|---|---|
| `platform.default` | `PlatformMockDomain` | the tables above; carries the three scenarios |
| `platform.empty` | `EmptyPlatformDomain` | no flags, no experiments, for everyone; no scenarios |
| `platform.flags_malformed` | `MalformedFlagsPlatformDomain` | the wrong-typed body above, for everyone; no scenarios |
| `platform.server_error` | `FailingPlatformDomain` | `500` `injected_failure`, whatever the auth; no scenarios |

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `status`, `body`), run on a fresh backend. A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_platform/tool/update_snapshots.dart`, review it, and update this file.
