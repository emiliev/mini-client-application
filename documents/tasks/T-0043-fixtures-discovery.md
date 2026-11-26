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
