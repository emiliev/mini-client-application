# Verification report — T-0051: `mc_fixtures_commerce`, the store mock domain

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, ADR-0011; not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0051-fixtures-commerce` @ `eac479e`
- **Simulator:** none (pure-Dart fixtures package, no UI)
- **Verdict:** PASS

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Whole AC5 gate script | `tool/checks/T-0051-AC5_gates.sh --role verifier` (own output base), output `documents/evidence/T-0051/verifier/AC5_gates.md` | PASS, all 11 gates |
| Pure-Dart closure | in the script | no Flutter markers; positive control (`mc_fixtures_media`) and negative control (throwaway target on both) show them |
| Registration, fixtures check | in the script | PASS; the package's own test target is seen, a throwaway production target is detected; tree clean afterwards |
| Tests (commerce, uncached) | in the script | 6/6 |
| Tests `//...` | in the script | 150/150 |
| Lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check` | in the script | PASS |
| Coverage (my own parser over the 6 `coverage.dat`, `package:mc_fixtures_commerce/*`, max hits per line) | `bazel coverage //utility/mc_fixtures_commerce/...` | 388/393 = **98.7 %** (>= 90 %) |
| Package tests via `fvm flutter test` (my mutation runner) | six test files | pass on the clean tree |

## Acceptance criteria
Independent probe (`documents/evidence/T-0051/verifier/probe_test.dart.txt`, run as a temporary test in the package and not committed as a test). It goes through two backends, a real identity domain (sign-in routes) and the comics domain. It has its own oracle, written from `CONTRACT.md` only: unit-level buy-2-get-1, per-line half-up by remainder arithmetic, largest remainder by `A*left % total`. `test/oracle.dart` was not used.

| AC | What I checked | Result |
|---|---|---|
| AC1 | Seed 42: banners, deals, categories, a category page, featured, a PUT and a case-insensitive promo apply give byte-identical raw bodies (8,508 bytes) on two fresh backends. 4 `T-0051-AC1` tests in `store_test.dart` | PASS |
| AC2 | `SectionFailingCommerceDomain(s)` for all 6 sections, all 9 routes probed each: exactly the section's routes answer 500 (cart: 4, the others: 1). The scenarios `store.deals_error` and `store.categories_error`, probed on all 9 routes, fail exactly their one route. Paging of `heroes` and `team-ups` with limits 1, 7, 13, 100: 60 ids, 60 distinct. An unknown section throws an `ArgumentError` naming `banners`, `cart` and `category_products` | PASS |
| AC3 | 8 carts against my oracle, all fields equal (every line total, cart total = sum of lines, every promotion's `discountCents` and `eligible`): (c1) 2 deal lines and 1 non-deal, no code; (c2) HEROES3 + SAVE25 + TAKE15 applied in the reverse of the stacking order, 4 lines, total 14,543; (c3) COSMIC3 over 7 units on 3 lines; (c4, c4b) SAVE10 and SAVE25 on prices ending in 5 (half-up), seeds 42 and 7; (c5) TAKE15 where the floor shares leave 3 cents over, so the largest remainder decides, plus a seed-7 cart with SAVE10 + TAKE5; (c6) TAKE5 then SAVE25 on a 2,5xx cart: TAKE5 goes `eligible: false` and takes 0 (percent before fixed). Stacking order confirmed as buy-2-get-1, then percent (half-up per line), then fixed. `grep` over `lib/` finds no `double`, rounding call, `toDouble` or `/` on a money path (only a doc comment and an enum name). The package has 23 `T-0051-AC3` tests in `cart_test.dart` and 7 in `money_test.dart` | PASS |
| AC4 | Every typed code and status: `invalid_quantity` 400 (100, -1, 1.5, "2"), `invalid_body` 400 (list body, non-string code), `unknown_product` 404, `out_of_stock` 409 (sold out, and over stock), `unknown_promo` 404, `promo_not_applicable` 409. Ids `99999999999999999999`, `0500060`, `00`, `-500060`, `5e5`, `+500060` give 404 `unknown_product` with `productId` echoed as sent. `DELETE ...promo?code=` blank gives 400 `invalid_parameter`. All 4 cart routes: no bearer 401, expired bearer 401. Two real users (u-100, u-101) signed in through `/v1/auth/sign-in`: u-101 sees an empty cart with no codes while u-100 has a line and a code, and u-100's cart keeps only its own line afterwards. The cart persists across two Dio clients on the backend, and `reset()` empties both carts | PASS |
| AC5 | Snapshots: 35 present; I changed `"totalCents": 0` to `1` in `cart_empty.json` and the contract test went red (reverted). All 360 product ids resolve on `GET /v1/comics/{id}` (200) for seeds 42 and 7. Purity, registration, fixtures check with negative controls, and `T-0051-AC5_gates.sh`: PASS (above). Coverage 98.7 % (above). `git diff origin/main...HEAD` outside the package, the task's docs and evidence, F-0051 and the gate script: `pubspec.yaml` (workspace entry) and `utility/mc_fixtures_comics/lib/mc_fixtures_comics.dart` (one line: `seriesIdBase` exported). `pubspec.lock` unchanged. Globs use `MC_GENERATED_DART` (BUILD and gates pass) | PASS |

## Mutations (10 of my own, run with `fvm flutter test` on the six test files)
| # | Mutation | Result |
|---|---|---|
| M1 | Percent computed on the line subtotal, not on what buy-2-get-1 left (stacking order) | killed (4 failing) |
| M2 | Half-up `+ 50` changed to `+ 49` | killed (6) |
| M3 | Largest-remainder sort reversed | killed (5) |
| M4 | The cart ignores the deal price | killed (4) |
| M5 | One shared cart for every user | killed (3) |
| M6 | Id guard `{0,17}` widened to `{0,40}` (overlong id) | killed (3) |
| M7 | Buy-2-get-1 unit sort ascending instead of descending (wrong unit free) | killed (7) |
| M8 | Fixed minimum `>=` changed to `>` | killed (4) |
| M9 | Fixed minimum checked against the original subtotal, not what is left | killed (9) |
| M10 | Stock boundary `>` changed to `>=` | killed (4) |

All 10 killed, none survived. Every mutation was reverted (`git status` clean).

**`mutations.sh` build failure:** I appended `int broken = ;` to `pricing.dart` and ran `bazel test //utility/mc_fixtures_commerce/...` as the script does. The log has `Build did NOT complete` once and zero `FAILED in` lines. The script tests `Build did NOT complete` first and counts it as `broken`, never as killed (`mutations.sh:56-59`). The shipped log ends `killed=100 survived=0 broken=0`.

## Test-integrity audit
- Tests deleted, skipped or weakened: none (the package is all new files; the `skip(3)` at `fixture_sets_test.dart:68` is `Iterable.skip`).
- Lint suppressions added: none (a grep for `// ignore` over the package has no hits).
- Golden files updated: none (the snapshot JSON files are new; one was edited and reverted by me).
- Every AC has `T-0051-ACn` tests: AC1 4, AC2 23, AC3 31, AC4 20, AC5 11.

## Visual acceptance (UI tasks)
Not applicable.

## Issues found
None. Minor observation only: the task Outcome quotes coverage 377/382, the current run measures 388/393 (both 98.7 %; line counts moved in the review round).

## Notes for the Tech Lead
- The scratch probe is kept as `documents/evidence/T-0051/verifier/probe_test.dart.txt` (a `.txt`, so no glob picks it up).
- The Bazel output base `/tmp/mc-ob-T-0051-verifier` was shut down.
