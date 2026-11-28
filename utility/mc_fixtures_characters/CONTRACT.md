# Characters contract (`mc_fixtures_characters`)

Our own domain-first contract (F-0003): a paginated envelope plus image path and variant. It claims no compatibility with any real API. Content is invented; there is no third-party art.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. The clock is fixed at `2026-01-01T00:00Z`.

## Routes

| Route | Purpose |
|---|---|
| `GET /v1/characters` | Page of character summaries |
| `GET /v1/characters/:id` | One character in detail |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `GET /v1/characters`

| Query | Type | Default | Rule |
|---|---|---|---|
| `offset` | int | 0 | `>= 0` |
| `limit` | int | 20 | 1 to 100 |
| `nameStartsWith` | string | none | case-insensitive prefix of `name`; empty means no filter |
| `team` | string | none | a team **id**: the team's name in lower case with each run of other characters as one `-` (`Harbor Watch` is `harbor-watch`; `teamIdOf` in the package). Case-insensitive; empty means no filter; an id nobody has (`red`) matches nothing (`total: 0`), it is not an error. `characters_list`'s `initialTeamId` and `characters_search`'s team chips send the same ids (T-0071) |
| `orderBy` | enum | `name` | `name`, `-name`, `modified`, `-modified`; ties break on `id`, so the order is total |

Response `200`:

```json
{
  "offset": 30, "limit": 30, "total": 1500, "count": 30,
  "results": [
    {
      "id": 100480, "name": "Spindle Alchemist", "description": "...",
      "modified": "2023-07-13T00:00:00.000Z",
      "thumbnail": {"path": "mock-asset://characters/014", "variant": "portrait_medium"}
    }
  ]
}
```

`total` counts the matches of the whole query (not the page); `count` is `results.length`. An offset past the end gives `count: 0`.

A bad query value gives `400` with `{"error": {"code": "invalid_parameter", "message": "...", "parameter": "limit"}}`.

### `GET /v1/characters/:id`

`200` returns the summary fields plus `powers` (3 strings, sorted), `team`, `origin`, `firstAppearanceYear`, `appearances` (`comics`, `series`, `events`), `aliases` and `stats` (T-0067).

| Field | Shape |
|---|---|
| `aliases` | 0 to 2 distinct strings of the form `The <word>`; none ends like the character's own name. The synthetic sets have none |
| `stats` | an object with exactly the keys `combat`, `durability`, `energy`, `intelligence`, `speed` and `strength`, each an integer from 1 to 100. The synthetic sets compute them from the index: `1 + (index * 7 + k * 13) mod 100` for the k-th stat in the order `intelligence`, `strength`, `speed`, `durability`, `energy`, `combat` |

`aliases` and `stats` depend on the seed and were added without moving any earlier field (they are drawn last). Seed 42: `100001` (`Spirit Warden`) has aliases `The Falconer` and `The Smith` and strength 94; `100000` has none.

An unknown or non-numeric id gives `404` with `{"error": {"code": "character_not_found", "message": "...", "id": "<raw id>"}}`.

### Errors from the engine

| Status | `error.code` | When |
|---|---|---|
| 404 | `not_found` | No mock route (the body names the path) |
| 500 | `handler_error` | A handler threw |
| any | `injected_failure` | A `FailureRule` of kind `http(status)` |

## Images

`thumbnail` is an `ApiImage`: `path` plus `variant` (`portrait_small`, `portrait_medium`, `portrait_large`, `standard`, `landscape`). Paths are `mock-asset://characters/<id>` with `id` from `000` to `023`; `BundledImageResolver` in `mc_fixtures_media` turns them into bundled assets (1x, 2x, 3x).

## Test-facing facts (seed 42)

| Fact | Value |
|---|---|
| Characters | 1,500, all names unique |
| First name in order | `Amber Alchemist` |
| `nameStartsWith=spi` | matches the aliases Spindle, Spirit, Spiral and Spire (152 characters); `Sparrow *` does not match |
| Page 2 at 30 per page | `offset=30&limit=30` |
| Teams | `The Lantern Circle` (`the-lantern-circle`), `Harbor Watch` (`harbor-watch`), `Northern Compass` (`northern-compass`), `The Quiet Ones` (`the-quiet-ones`), `Copper Street Collective` (`copper-street-collective`), `Skyline Guild` (`skyline-guild`), `The Undertow` (`the-undertow`), `Open Road` (`open-road`). Every character has one, drawn from the seed; the synthetic sets give everyone the empty team, so any `team` filter matches nothing there |
| Names | do not depend on the seed; every other field does |

## Scenarios

| Name | Effect |
|---|---|
| `characters.empty` | `GET /v1/characters` returns a well-formed page with `total: 0` |
| `characters.server_error` | `GET /v1/characters` fails with `500` |

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `charactersFixtureSets`. A test registers them once (`charactersFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario (`the backend serves {'characters.default'}`). Each set serves both routes with the paging, validation and envelope above.

| Set | Cast | Test-facing facts |
|---|---|---|
| `characters.default` | `CharactersMockDomain` (the 1,500 above, seed 42) | First page at 30: `Amber Alchemist` (id 100486) to `Amber Striker`; index 12 is `Amber Herald`; offset 30 starts at `Amber Tinker` |
| `characters.paged_45` | `SyntheticCharactersDomain(45)` | `Hero 01` to `Hero 45` (ids 100000 to 100044), in that order; at 30 per page: two pages (30 + 15); thumbnails cycle `000` to `023`; no scenarios |
| `characters.empty` | `SyntheticCharactersDomain(0)` | `total: 0`, `count: 0`; every detail is `404`; no scenarios |

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `status`, `body`). A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_characters/tool/update_snapshots.dart`, review it, and update this file.
