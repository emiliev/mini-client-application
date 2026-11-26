# Comics contract (`mc_fixtures_comics`)

Our own domain-first contract (F-0003): the same paginated envelope and image shape as `mc_fixtures_characters`. It claims no compatibility with any real API. Content is invented; there is no third-party art.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. The clock is fixed at `2026-01-01T00:00Z`; every release date is before it.

## Routes

| Route | Purpose |
|---|---|
| `GET /v1/comics` | Page of comic summaries |
| `GET /v1/comics/:id` | One comic in detail |
| `GET /v1/series/:id` | One series, with its comic ids |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

### `GET /v1/comics`

| Query | Type | Default | Rule |
|---|---|---|---|
| `offset` | int | 0 | `>= 0` |
| `limit` | int | 20 | 1 to 100 |
| `titleStartsWith` | string | none | case-insensitive prefix of `title`; empty means no filter |
| `characterId` | int | none | only comics featuring that character; an id nobody features matches nothing |
| `orderBy` | enum | `title` | `title`, `-title`, `releaseDate`, `-releaseDate`; ties break on `id`, so the order is total |

Filters combine (`characterId` and `titleStartsWith` both apply). Response `200`:

```json
{
  "offset": 0, "limit": 3, "total": 2400, "count": 3,
  "results": [
    {
      "id": 500060, "title": "Amber Chronicles #1", "issueNumber": 1,
      "seriesId": 400003, "releaseDate": "2010-01-05",
      "cover": {"path": "mock-asset://characters/003", "variant": "portrait_large"}
    }
  ]
}
```

`total` counts the matches of the whole query (not the page); `count` is `results.length`. An offset past the end gives `count: 0`. `releaseDate` is a `YYYY-MM-DD` date. Note that `title` sorts as text, so `#10` comes before `#2`.

A bad query value gives `400` with `{"error": {"code": "invalid_parameter", "message": "...", "parameter": "limit"}}`.

### `GET /v1/comics/:id`

`200` returns the summary fields plus:

| Field | Shape |
|---|---|
| `description` | string |
| `series` | `{id, title}`, the same series as `seriesId` |
| `creators` | 2 to 6 credits `{id, name, role}`; roles come in order `writer`, `penciller`, `inker`, `colorist`, `letterer`, `cover_artist`, and `writer` and `penciller` are always present |
| `characterIds` | 1 to 6 ids in `mc_fixtures_characters`, ascending (see Cross-links) |
| `price` | `{amountCents, currency}`; `currency` is `USD`; 299 to 599 |
| `pageCount` | 24 to 56, in steps of 8 |
| `variants` | 0 to 2 cover variants `{label, cover}` with distinct labels |

An unknown or non-numeric id gives `404` with `{"error": {"code": "comic_not_found", "message": "No comic with id <raw id>", "id": "<raw id>"}}`.

### `GET /v1/series/:id`

`200` returns `id`, `title`, `description`, `startYear`, `endYear`, `cover`, `comicCount` and `comicIds` (the series' comics in issue order). An unknown or non-numeric id gives `404` with `error.code` `series_not_found` and the raw `id`.

### Errors from the engine

| Status | `error.code` | When |
|---|---|---|
| 404 | `not_found` | No mock route (the body names the path) |
| 500 | `handler_error` | A handler threw |
| any | `injected_failure` | A `FailureRule` of kind `http(status)` |

## Images

Every cover, series cover and variant cover is an `ApiImage`: `path` plus `variant` (`portrait_large` here). Paths are `mock-asset://characters/<id>` with `id` from `000` to `023`. Comics reuse the bundled characters placeholders (they are generated and trademark-free; P-009, P-011), so no comics set was added to `mc_fixtures_media`. `BundledImageResolver` turns them into bundled assets (1x, 2x, 3x).

## Cross-links

- `characterIds` are ids in `mc_fixtures_characters`: `100000` to `101499` (1,500 characters). `GET /v1/comics?characterId=<id>` is the reverse lookup.
- This package is pure Dart, so it does not import `mc_fixtures_characters` or `mc_fixtures_media` (both carry Flutter). `lib/src/data/links.dart` states the ID range and the art set instead, and the provider-contract test checks each constant against the real packages.

## Test-facing facts (seed 42)

| Fact | Value |
|---|---|
| Series | 120, ids `400000` to `400119`, titles unique (`<word> <noun>`) |
| Issues per series | 20, ids `500000` to `502399` (series `n`, issue `k`: `500000 + 20n + k - 1`) |
| Comics | 2,400 |
| Creators | a pool of 60, ids `300000` to `300059` |
| First titles in order | `Amber Chronicles #1`, `#10`, `#11` |
| `titleStartsWith=spi` | matches the series Spindle and Spire (400 comics); `Sparrow *` does not match |
| `characterId=100000` | 6 comics |
| Page 2 at 40 per page | `offset=40&limit=2` starts at `Amber Gambit #1` |
| `GET /v1/comics/500000` | `Spindle Chronicles #1`, series `400000` |
| Titles, series and creator names | do not depend on the seed; every other field does |

## Scenarios

| Name | Effect |
|---|---|
| `comics.empty` | The list returns a well-formed page with `total: 0`; every comic and series detail is a `404` |
| `comics.server_error` | All three routes fail with `500` (`injected_failure`) |

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `comicsFixtureSets`. A test registers them once (`comicsFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario (`the backend serves {'comics.default'}`). Each set serves all three routes. The first three also exist as scenarios on the default domain; the sets are for tests that need only that domain.

| Set | Cast | Test-facing facts |
|---|---|---|
| `comics.default` | `ComicsMockDomain` (the 2,400 above, seed 42) | See the table above |
| `comics.paged_45` | `SyntheticComicsDomain(45)` | `Issue 01` to `Issue 45` (ids `500000` to `500044`) in one series, `Synthetic Series` (id `400000`, `comicCount` 45); at 30 per page: two pages (30 + 15); covers cycle `000` to `023`; no creators, characters or variants; no scenarios |
| `comics.empty` | `SyntheticComicsDomain(0)` | `total: 0`, `count: 0`; every comic and series detail is `404`; no scenarios |
| `comics.server_error` | `FailingComicsDomain` | every route answers `500` with `error.code` `server_error`; no scenarios |

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `status`, `body`). A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_comics/tool/update_snapshots.dart`, review it, and update this file.
