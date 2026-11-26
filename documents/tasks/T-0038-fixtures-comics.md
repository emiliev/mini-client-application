# T-0038: `mc_fixtures_comics`, the comics mock domain (P1-08 subset, U41)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0038-fixtures-comics` |
| Created | 2026-11-26 |
| Depends on | T-0018 (`mc_mocked_backend`, `mc_fixtures_characters`, `mc_fixtures_media`), T-0031 (sealed `ResolvedImage`) |
| Related | plan 01 U41, P1-08; `utility/mc_fixtures_characters/CONTRACT.md`; F-0015; ADR-0005 (mocked backend) |

## Goal
The comics domain that the SC exemplar `comics_details` (P1-18) and later the publishing features read. Same shape and quality bar as `mc_fixtures_characters`.

## Scope
- **In:**
  - `utility/mc_fixtures_comics` (archetype UM): a deterministic, seeded universe of comics, series, creators and variants. It cross-links to characters by the IDs `mc_fixtures_characters` uses, without importing its internals. If needed, use a small shared ID contract, or `addDomain` composition through the public API only.
  - Endpoints:
    - `GET /v1/comics` (offset/limit, `titleStartsWith`, `characterId`, `orderBy`)
    - `GET /v1/comics/{id}` (detail: title, issue number, description, cover `ApiImage`, creators, characters, price, page count, release date)
    - `GET /v1/series/{id}`
  - Every endpoint has `default`, `empty` and `server_error` fixture sets. Write a `CONTRACT.md` in the same style as the characters one.
  - Cover art: reuse `mc_fixtures_media`'s bundled placeholder sets. Add a comics set only if needed, generated and trademark-free (P-009, P-011).
- **Out:** events, identity, writes (favourites live in the identity domain, T-0039), and discovery search.

## Acceptance criteria
- **T-0038-AC1:** Given seed 42, when one request sequence runs on two backends, then the responses are byte-identical (determinism, as P1-06 AC1).
- **T-0038-AC2:** Every endpoint has `default`, `empty` and `server_error` sets. `GET /v1/comics/{unknown}` is a 404 whose body names the id. Paging is stable and total.
- **T-0038-AC3:** The provider contract snapshots match. Every `characterId` a comic references resolves in `mc_fixtures_characters`. Every cover `ApiImage` resolves to a bundled asset.
- **T-0038-AC4:** The package is pure Dart (closure check as in T-0030-AC7), registered in the workspace, at ≥ 90 % coverage, and passes the T-0031-AC6 fixtures check (no production feature or DS target depends on it). Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format.

## Log
- 2026-11-26: Created and dispatched (TL).
- 2026-11-26: Engineer: package, tests, CONTRACT.md and gates done (evidence in `documents/evidence/T-0038/engineer/AC4_gates.md`).

## Outcome
`utility/mc_fixtures_comics` (archetype UM) is registered in the workspace. It serves `GET /v1/comics`, `GET /v1/comics/:id` and `GET /v1/series/:id` over 120 series x 20 issues = 2,400 comics, a pool of 60 creators, and 0 to 2 variants per comic. Seed 42 is deterministic. See `CONTRACT.md` for the shapes and facts.

| AC | Evidence |
|---|---|
| AC1 | `comics_test.dart`: `T-0038-AC1` (byte-identical on two backends over an 11-request sequence, plus a different-seed negative control) |
| AC2 | `comics_test.dart` and `fixture_sets_test.dart`: `T-0038-AC2` (stable, total paging in four orders; 404s that name the id; `default`, `empty`, `server_error` as scenarios and as fixture sets; `paged_45`) |
| AC3 | `provider_contract_test.dart`: `T-0038-AC3` (11 snapshots, manifest and CONTRACT.md in step, every `characterId` resolves in `mc_fixtures_characters`, every cover and variant cover resolves to an existing asset, resolver negative control) |
| AC4 | `tool/checks/T-0038-AC4_gates.sh`: pure closure (positive control `mc_fixtures_characters`), registration, fixtures check (positive and negative controls), `test //...` 88/88, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, coverage 98.3 % (228/232) |

Decisions:
- **Pure Dart means no import of `mc_fixtures_characters` or `mc_fixtures_media`**: both carry Flutter, which fails the T-0030-AC7 closure. The ID range (`100000` + 1,500) and the art set (`characters`, 24) are constants in `lib/src/data/links.dart`. Tests check them against the real packages, so a drift fails a test.
- Covers reuse the `characters` placeholder set (`portrait_large`); no comics set was added.
- Fixture sets are `comics.default`, `comics.paged_45`, `comics.empty` and `comics.server_error`. The same `empty` and `server_error` also exist as scenarios on the default domain.
- No lock file changed: the new workspace member adds no external dependency.
- Not done: no `// ignore:`, no test skipped or weakened.
