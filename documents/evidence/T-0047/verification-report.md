# Verification report — T-0047: `mc_fixtures_library`, the reading-lists mock domain

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier per ADR-0011, not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0047-fixtures-library` @ `35a9be6`
- **Simulator:** none (pure-Dart fixtures task, no UI, no e2e AC)
- **Verdict:** PASS

## Gates re-run independently
Bazel with `--output_base=/tmp/mc-ob-T-0047-verifier` (shut down at the end).

| Gate | Command | Result |
|---|---|---|
| AC5 gates script | `tool/checks/T-0047-AC5_gates.sh --role verifier` (report: `verifier-AC5_gates.md`) | PASS, all 11 rows |
| Purity | closure of the library: 1358 targets, 0 Flutter markers | PASS |
| Purity controls | script: media package (positive), Flutter dep added to the library BUILD (negative); mine: `characters_list` closure has 292 Flutter-marker lines, library 0 | PASS |
| Fixtures check | script, with positive and negative controls | PASS |
| `test //...` | script | 127/127 pass (cached) |
| lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check` | script | PASS |
| Clean tree | `git status` after the script: clean; both BUILD files restored (script verifies with `cmp`, and `git status` shows no diff) | PASS |
| Library tests | `fvm flutter test utility/mc_fixtures_library/test` from the repo root | 81/81 pass |
| Coverage | `flutter test --coverage`, my own awk lcov parser | 194/197 = 98.5 % (`domain.dart` 34/37, the rest 100 %) |

Note: the contract test needs the repo root as cwd (as under Bazel). Run from the package directory it fails to load; that is a harness detail, not a defect.

## Acceptance criteria
My own probe test (`verifier-probe.dart.txt`, run as an untracked test, then removed from the package) used two real users signed in via `POST /v1/auth/sign-in` on a backend with identity, comics and library domains. It passed 4/4.

| AC | Scenario (short) | Mapped test(s) / probe | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0047-AC1 | 6-request write sequence byte-identical on two seed-42 backends and after `reset()` | `library_test.dart` `T-0047-AC1`; probe P-AC1 | yes (compares raw response text) | PASS |
| T-0047-AC2 | create 201 and listed; update, reorder (exact order sent, add/drop), delete 204 then 404; persistence until `reset()`; user B gets 404 on GET, PUT, PUT items, DELETE of A's list and does not see it in the list; `updatedAt` after two edits puts the later edit first (`[l-2, l-3, new, l-1]`) | `library_test.dart` `T-0047-AC2`; probe P-AC2 | yes | PASS |
| T-0047-AC3 | name blank, 60 vs 61, emoji 60 vs 61 (runes); description 280 vs 281; `Public` and `PRIVATE` rejected; duplicates, unknown id, 100 ok vs 101; non-object body gives `invalid_body` with `parameter: "body"`; order auth (401), then 404, then 400; no bearer, expired, refresh-as-bearer, `Basic`, `bearer` (lowercase), raw token all 401, and the same headers 401 on `GET /v1/me`; `userForAuthorization` is the one function `GET /v1/me` and the favourites routes call (`identity_handlers.dart:122,136`), library handlers call the same one, so there is no second scheme | `validation_test.dart`, `library_test.dart`, `identity_test.dart` `T-0047-AC3`; probe P-AC3 | yes | PASS |
| T-0047-AC4 | 19 snapshots match; tampering with `get.json` turns `T-0047-AC4: get matches its snapshot` red; item ids resolve on `GET /v1/comics/{id}` for seeds 42 and 7, thumbnails are `mock-asset://characters/NNN`; `library.empty` follows the seed (seed 42 and 7: item title equals the comics endpoint's); first empty-state id is `l-1001`, and a test pins non-aliasing | `provider_contract_test.dart`, `fixture_sets_test.dart` `T-0047-AC4`; probe P-AC4 | yes | PASS |
| T-0047-AC5 | gates, purity with controls, registration, 98.5 % coverage | `tool/checks/T-0047-AC5_gates.sh` | yes (controls actually fail the check when broken) | PASS |

## Mutations (10 of my own, `verifier-mutations.sh` and `.log`)
Baseline 81/81. Each mutant was run from the repo root and the file restored. Each failed 2 to 7 tests, with no build breaks.

| # | Mutation | Result |
|---|---|---|
| M1 | seed-following scenario pinned to `comicsFor(42)` | killed (-2) |
| M2 | empty-state id offset 1001 to 1 | killed (-2) |
| M3 | name max 60 to 61 | killed (-5) |
| M4 | list not found 404 to 403 | killed (-7) |
| M5 | missing bearer falls back to a valid user | killed (-3) |
| M6 | `_find` searches every user's lists (ownership) | killed (-3) |
| M7 | duplicate check disabled | killed (-3) |
| M8 | `comicIds` max 100 to 101 | killed (-3) |
| M9 | description max 280 to 281 | killed (-5) |
| M10 | `PUT .../items` sorts the submitted ids | killed (-2) |

Survivors: 0. (My first pass ran the tests from the package directory, where the contract test fails to load; I discarded it and re-ran every mutation from the repo root, as above.)

## Test-integrity audit
- Tests deleted, skipped or weakened: none. The only file deleted in `git diff origin/main` is `T-0048-...md`, which is a file that `origin/main` gained after this branch's merge (`git diff origin/main...35a9be6` has no deletions).
- Lint suppressions added: none (no `// ignore` and no `skip:` in the package).
- `mc_fixtures_identity` change: one `show` entry (`userForAuthorization`) in the barrel export plus one test, `T-0047-AC3 userForAuthorization is the check GET /v1/me applies`. Minimal, as required.
- Goldens: none. Snapshots are new; a tampered snapshot is detected.
- Every AC has a `T-0047-ACn` test: AC1 and AC2 in `library_test.dart`, AC3 in `validation_test.dart`, `library_test.dart` and `identity_test.dart`, AC4 in `fixture_sets_test.dart` and `provider_contract_test.dart`, AC5 in `tool/checks/T-0047-AC5_gates.sh`. Globs use `MC_GENERATED_DART`.

## Visual acceptance
Not applicable.

## Issues found
None blocking. Informational (info):
1. (info) `domain.dart` has 3 uncovered lines (98.5 % total, above the 90 % threshold).
2. (info) The CONTRACT already documents the coupling to the library's own `ComicUniverse(seed)`; nothing further to do.

## Notes for the Tech Lead
- The worktree was clean after every run; no pushes. Evidence files are in `documents/evidence/T-0047/` (`verifier-*`).
- Bazel server for `/tmp/mc-ob-T-0047-verifier` shut down.
