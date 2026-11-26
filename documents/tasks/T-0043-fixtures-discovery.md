# T-0043: `mc_fixtures_discovery`, the global search mock domain (P1-10 subset, U48)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (fixtures; ADR-0011) |
| Branch | `fleet/T-0043-fixtures-discovery` |
| Created | 2026-11-26 |
| Depends on | T-0018/T-0038 (`mc_fixtures_characters`, `mc_fixtures_comics`, both pure Dart) |
| Related | plan 01 U48, P1-10 AC5; `CONTRACT.md` of the characters and comics domains; ADR-0005 |

## Goal
The search backend for the SR exemplar `discovery_search` (P1-19). One query searches characters and comics and returns results grouped by domain, ranked the same way every time.

## Scope
- **In:**
  - `utility/mc_fixtures_discovery` (UM, pure Dart). It reads the characters and comics universes through their public APIs; no copies of their data.
  - `GET /v1/search?q=&types=character,comic&limit=` returns `{query, groups: [{type, total, results: [{id, type, title, subtitle?, thumbnail}]}]}`.
  - Ranking is deterministic:
    1. exact match
    2. prefix
    3. word-prefix
    4. substring
    5. ties by title, then id
  - Matching ignores case and diacritics.
  - `q` is trimmed. A `q` shorter than 2 characters gives 400 `query_too_short`.
  - `GET /v1/search/suggestions?q=` returns the top 5 titles across types.
  - `default`, `empty` and `server_error` sets and scenarios exist, with one identical `server_error` body for both (T-0038 lesson). Write a `CONTRACT.md`.
- **Out:** events, recommendations, trending, home/explore (later P1-10 work).

## Acceptance criteria
- **T-0043-AC1:** Determinism: for seed 42, the same query sequence on two backends gives byte-identical responses.
- **T-0043-AC2:** Given `q=spi`, then every result's title matches the query (prefix, word-prefix or substring, ignoring case and diacritics), results are grouped by domain in the order character then comic, and the ranking follows the documented tiers with tie-breaks. A test fails if the tier order or the tie-break is removed. P1-10 AC5: a search for a curated name returns hits from both domains, ranked deterministically.
- **T-0043-AC3:** Contract: the snapshots match. Every result id resolves on its own domain's detail endpoint. Every thumbnail resolves to a bundled asset.
- **T-0043-AC4:** Validation: `q` too short gives 400. `types` with an unknown type gives 400. `limit` bounds work as in the other domains. The `empty` and `server_error` sets behave as documented.
- **T-0043-AC5:** The package is pure Dart (closure check with a negative control) and registered, has ≥ 90 % coverage, and passes the fixtures check. Gates pass: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format. Globs use `MC_GENERATED_DART`.

## Log
- 2026-11-26: Created and dispatched (TL).
- 2026-11-26: Engineer handoff (Sonnet). Package, tests, CONTRACT.md, snapshots, gates script and mutation evidence are on `fleet/T-0043-fixtures-discovery`; `origin/main` was merged (nothing new), no lock file changed.

## Outcome
`utility/mc_fixtures_discovery` (archetype UM, pure Dart) is registered in the workspace. It indexes the characters (1,500) and comics (2,400) universes through their public APIs (`CharacterUniverse.byName`, `ComicUniverse.byTitle`) and serves `GET /v1/search` and `GET /v1/search/suggestions`. See `CONTRACT.md` for the shapes and the seed-42 facts.

| AC | Evidence |
|---|---|
| AC1 | `search_test.dart`: `T-0043-AC1` (13 requests, byte-identical on two backends and on a repeat; seed 7 changes art but not titles) |
| AC2 | `ranking_test.dart` and `search_test.dart`: `T-0043-AC2` (folding; each tier pair pinned with a title order that contradicts the tier order; title, id and type tie-breaks pinned with reversed inputs; endpoint ranking compared with an independent oracle built from the universes for 6 queries; group order; suggestions; P1-10 AC5 with `spindle`) |
| AC3 | `provider_contract_test.dart`: `T-0043-AC3` (14 snapshots, manifest and CONTRACT.md in step, every result id resolves on its own detail endpoint with equal title and image for seeds 42 and 7, every character and comic is findable by its exact title, every thumbnail resolves to an existing asset, resolver negative control) |
| AC4 | `search_test.dart` and `fixture_sets_test.dart`: `T-0043-AC4` (8 `q` cases, 6 `types` cases, 8 `limit` cases, per-group limits, check order; `empty` and `server_error` as sets and scenarios, same bodies) |
| AC5 | `tool/checks/T-0043-AC5_gates.sh`: pure closure (positive control `mc_fixtures_media`), registration, fixtures check (positive and negative controls), `test //...` 115/115, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, coverage 97.3 % (143/147). Report: `documents/evidence/T-0043/engineer/AC5_gates.md` |

Mutations: `documents/evidence/T-0043/engineer/mutations.sh` (`MC_TASK=T-0043 MC_ROLE=engineer`), log `mutations.log`: **33/33 killed**, none survived, none broke the build. Every tier (4), the boundary check, the title/type/id tie-breaks, each folding step, group order, limits and bounds are each pinned.

Decisions:
- **Ranking.** Tiers exact, prefix, word-prefix, substring. A word-prefix is an occurrence right after any non-letter, non-digit. Ties: title as written (code units), then type (character first), then id. The type step only matters for suggestions, which rank across types.
- **Groups.** One group per requested type, always character then comic; a group with no match is present with `total: 0`. `limit` is per group; `total` is the full match count.
- **Suggestions** are the best 5 distinct title strings. A title shared by a character and a comic appears once.
- **Validation order** is `q`, `types`, `limit`. `types` is strict (lower case; an empty value or entry is a 400). A missing `q` is `query_too_short`.
- **Sets:** `discovery.default`, `discovery.empty`, `discovery.server_error`; the empty and server_error sets answer the same bodies as the scenarios (tested). The `server_error` body is one shared `injected_failure` (T-0038 lesson).
- Added `IndexedDiscoveryDomain(SearchIndex)` so tests (and later SR feature tests) can serve entries with duplicate titles. It is not a named set.
- `tool/checks/T-0043-AC5_gates.sh` is the T-0038 gates script adapted; it sits outside the task's listed edit scope, as the T-0038 one did.
- No lock file changed. No `// ignore:`, no test skipped, deleted or weakened.
