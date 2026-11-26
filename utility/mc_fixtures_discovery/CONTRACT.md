# Discovery contract (`mc_fixtures_discovery`)

Our own domain-first contract (F-0003): global search over the characters and comics domains. It claims no compatibility with any real API. Content is invented; there is no third-party art.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. The domain owns no data. It indexes `mc_fixtures_characters` and `mc_fixtures_comics` through their public APIs for the backend's seed, so a name or title changes there and here together. Events, recommendations, trending and home/explore come later (P1-10).

## Routes

| Route | Purpose |
|---|---|
| `GET /v1/search` | Ranked results, grouped by domain |
| `GET /v1/search/suggestions` | The top 5 titles across domains |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `GET /v1/search`

| Query | Type | Default | Rule |
|---|---|---|---|
| `q` | string | none | trimmed; at least 2 characters after trimming (counted as characters, not bytes); a missing `q` counts as empty |
| `types` | list | `character,comic` | comma-separated, each exactly `character` or `comic` (lower case, spaces around an entry are ignored); anything else, an empty entry or an empty value is a `400`; repeats collapse |
| `limit` | int | 20 | 1 to 100; applies to each group, not to the whole answer |

Checks run in the order `q`, `types`, `limit`; the first failure is the answer. Response `200`:

```json
{
  "query": "spi",
  "groups": [
    {
      "type": "character", "total": 152,
      "results": [
        {
          "id": 100480, "type": "character", "title": "Spindle Alchemist",
          "subtitle": "The Lantern Circle",
          "thumbnail": {"path": "mock-asset://characters/014", "variant": "portrait_medium"}
        }
      ]
    },
    {"type": "comic", "total": 400, "results": [ ... ]}
  ]
}
```

- `query` is `q` after trimming, as typed (case and marks kept).
- There is one group for each requested type, **always in the order `character`, `comic`**, whatever order `types` lists them. A group with no match is still present, with `total: 0` and `results: []`.
- `total` counts every match of the group, not the page; `results` holds the first `limit` of them.
- A result is `{id, type, title, subtitle?, thumbnail}`. `id` is the id on its own domain's detail endpoint (`GET /v1/characters/:id` or `GET /v1/comics/:id`), and `thumbnail` is the image that detail serves (a character's `thumbnail`, a comic's `cover`), so it resolves to a bundled asset. `subtitle` is a character's team (left out when it has none) and a comic's release year.

### Matching and ranking

Matching ignores case and diacritics: both the query and the title are lower-cased, their accents removed (`é` is `e`, `ß` is `ss`, `æ` is `ae`) and every run of whitespace made one space. The query is matched against the whole title. A title matches in the **first** of these tiers that applies:

| Tier | Rule | Example for `q=alp` |
|---|---|---|
| 1. exact | the title equals the query | `ALP` |
| 2. prefix | the title starts with the query | `Alpha Zulu` |
| 3. word-prefix | the query starts a later word: it occurs right after a character that is not a letter or digit | `Zeta Alp` |
| 4. substring | the query occurs anywhere else | `Kalpa` |

Inside a group, results are sorted by **tier, then title, then id**. The title is compared as written (code units, so `ALPHA` sorts before `Alpha`), the id numerically. The order is total, so it never depends on the order of the data. Across types (suggestions) the key is tier, title, **type** (`character` before `comic`) and id.

### `GET /v1/search/suggestions`

Same `q` rule and the same matching, over both types. Other parameters are ignored. Response `200`:

```json
{"query": "spi", "suggestions": ["Spindle Alchemist", "Spindle Artisan", "Spindle Bard", "Spindle Beacon", "Spindle Captain"]}
```

`suggestions` holds the best 5 **distinct** titles in the ranking order (a title shared by a character and a comic appears once), or fewer when fewer match.

### Errors

| Status | `error.code` | When | Extra fields |
|---|---|---|---|
| 400 | `query_too_short` | `q` is missing or shorter than 2 characters after trimming | `parameter: "q"`, `minLength: 2` |
| 400 | `invalid_parameter` | an unknown `types` entry, or `limit` outside 1 to 100 or not a plain integer | `parameter` |
| 404 | `not_found` | No mock route (the body names the path) | |
| 500 | `handler_error` | A handler threw | |
| any | `injected_failure` | A `FailureRule` of kind `http(status)` | |

Every error has `{"error": {"code", "message", ...}}`.

## Images

Thumbnails are the same `ApiImage` values the characters and comics domains serve: `mock-asset://characters/<id>` with `id` from `000` to `023` and variant `portrait_medium` (characters) or `portrait_large` (comics). `BundledImageResolver` turns them into bundled assets (1x, 2x, 3x). This package is pure Dart and imports no media package; the provider-contract test resolves every thumbnail against the real asset files.

## Test-facing facts (seed 42)

| Fact | Value |
|---|---|
| Index | 1,500 characters (ids `100000` to `101499`) and 2,400 comics (ids `500000` to `502399`); every title is unique within its type |
| `q=spi` | prefix matches only (152 characters and 400 comics); the first are `Spindle Alchemist` and `Spindle Chronicles #1` |
| `q=spindle` | hits from both groups; characters first, `Spindle Alchemist` ranks first, then `Spindle Artisan` |
| `q=Spire Warden` | one character, an exact match; no comic |
| `q=amber chronicles #1`, `types=comic` | 11 comics: `Amber Chronicles #1` (exact), then `#10` to `#19` (prefix, text order) |
| `q=chron` | 240 comics, all word-prefix (`Amber Chronicles #1`, `#10`, `#11`, ...); no character |
| `q=ard`, `types=character` | 160 characters, all substring (`Amber Bard`, `Amber Guardian`, ...) |
| `q=co` | characters in all three of prefix, word-prefix and substring |
| `/v1/search/suggestions?q=spi` | `Spindle Alchemist`, `Spindle Artisan`, `Spindle Bard`, `Spindle Beacon`, `Spindle Captain` |
| Independent of the seed | ids, names and titles, hence every ranking; the thumbnails and subtitles depend on it |

## Scenarios

| Name | Effect |
|---|---|
| `discovery.empty` | Both routes validate as usual, then search answers every requested group with `total: 0` and suggestions answer `[]` |
| `discovery.server_error` | Both routes fail with `500` (`injected_failure`) |

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `discoveryFixtureSets`. A test registers them once (`discoveryFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario (`the backend serves {'discovery.default'}`). Each set serves both routes. The set and the scenario of the same name answer the same bodies (`server_error` is `injected_failure` with status `500`, and `empty` answers what the empty index answers). A set is meant to be served with the characters and comics sets that its results link to.

| Set | Cast | Test-facing facts |
|---|---|---|
| `discovery.default` | `DiscoveryMockDomain` (the index above, seed 42) | See the table above |
| `discovery.empty` | `EmptyDiscoveryDomain` | nothing matches; `total: 0` in every requested group; no suggestions; validation unchanged; no scenarios |
| `discovery.server_error` | `FailingDiscoveryDomain` | both routes answer `500` with `error.code` `injected_failure`, the same body as the scenario; no scenarios |

`IndexedDiscoveryDomain(SearchIndex)` serves the same routes over entries a test builds itself (duplicate titles, tie-break cases). It is not a named set.

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `status`, `body`). A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_discovery/tool/update_snapshots.dart`, review it, and update this file.
