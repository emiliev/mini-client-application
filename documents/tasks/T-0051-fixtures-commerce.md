# T-0051: `mc_fixtures_commerce`, the store mock domain (P1-09 subset, U45)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-27 `7b6a1f4`; Verifier PASS `6b1ee59`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (fixtures; ADR-0011) |
| Branch | `fleet/T-0051-fixtures-commerce` |
| Created | 2026-11-27 |
| Depends on | T-0038 (`mc_fixtures_comics`), T-0039 (`mc_fixtures_identity`), T-0043/T-0047 (fixture conventions) |
| Related | plan 01 U45, P1-09 (AC5: a cart total equals the sum of line items after promotions, for 20 seeded carts), F077 (DB exemplar `store_home`, P1-21: "Given the deals endpoint failing, then only that section shows an error"); ADR-0005 |

## Goal
The backend for the DB exemplar `store_home` (P1-21). It has independent sections (banners, deals, categories, featured products), each with its own endpoint so one can fail alone. It also has a cart with promotions, for later commerce features.

## Scope
- **In:** `utility/mc_fixtures_commerce` (UM, pure Dart). Products are comics from `mc_fixtures_comics`' public API, each with a price, a `currency: "EUR"` and stock.
  - `GET /v1/store/banners`: 3–5 banners with title, subtitle, image and target (a comic id, a category, or the search query).
  - `GET /v1/store/deals`: discounted products (original and deal price, ends-at on a fixed clock).
  - `GET /v1/store/categories`: name, count and image.
  - `GET /v1/store/categories/{id}/products`: offset/limit paging.
  - `GET /v1/store/featured`.
  - Cart, which needs a bearer through `mc_fixtures_identity`'s `userForAuthorization`:
    - `GET /v1/me/cart`
    - `PUT /v1/me/cart/items/{productId}` with `{quantity}`, where 0 removes the line
    - `POST /v1/me/cart/promo` with `{code}`
    - `DELETE /v1/me/cart/promo`

    The cart is kept per user until `reset()`.
  - Promotions: percent-off, fixed-off with a minimum subtotal, and buy-2-get-1 on a category. They stack in a documented order.
  - **All money is integer cents**, never floats. Rounding is documented: half-up per line.
  - Typed validation codes: `unknown_product`, `out_of_stock`, `invalid_quantity` (outside 0–99), `unknown_promo`, `promo_not_applicable`.
  - The `default`, `empty` and `server_error` sets and scenarios, **plus a per-section failure scenario for each section** (for example `store.deals_error`) so P1-21 AC6 can fail just one section. Bodies match their sets exactly (T-0043 convention). Add a `CONTRACT.md`.
- **Out:** checkout, orders, payments, reviews (later).

## Acceptance criteria
- **T-0051-AC1:** Determinism, as in P1-06 AC1. The same requests return byte-identical bodies for seed 42.
- **T-0051-AC2:** Each section endpoint works on its own. Each per-section failure scenario fails only its own route; the other sections still return 200. Category paging is stable and total.
- **T-0051-AC3:**
  - **Cart arithmetic:** the cart total equals the sum of line totals after promotions, for 20 seeded carts. This is P1-09 AC5, checked against an independent oracle in the test.
  - **Promotions:** each promotion type and its stacking order are pinned by mutations.
  - **Money:** integer cents throughout, with a test for the documented rounding.
- **T-0051-AC4:** Validation:
  - every typed code is pinned;
  - auth: 401 without a bearer;
  - another user's cart is never visible;
  - the cart persists until `reset()`.
- **T-0051-AC5:** Contract and packaging:
  - the snapshots match, product ids resolve on `GET /v1/comics/{id}`, and images resolve;
  - pure Dart (closure check with a negative control), registered, coverage ≥ 90 %;
  - the fixtures check and gates pass;
  - globs use `MC_GENERATED_DART`.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Sonnet). `utility/mc_fixtures_commerce` built and registered (root `pubspec.yaml`; `pubspec.lock` unchanged). No file outside the package, this task file, `tool/checks/T-0051-AC5_gates.sh`, `documents/evidence/T-0051/engineer/` and `F-0051` was touched.
- 2026-11-27: Decisions inside the scope (all in `CONTRACT.md`):
  - A product is a comic (issues 1 to 3 of each series, 360 products), with its own EUR price (299 to 1,999 cents) and stock. Categories are `series index mod 6`.
  - The cart charges the deal price for a deal product.
  - Status codes: `unknown_product` 404, `invalid_quantity` 400, `out_of_stock` 409, `unknown_promo` 404, `promo_not_applicable` 409 with a `reason`, plus `invalid_body`, `unknown_category` and `invalid_parameter`.
  - Stacking order (fixed, independent of the order the codes are applied in): buy-2-get-1, then percent (half-up per line), then fixed (shared over the lines by largest remainder). One code per kind. A code whose condition no longer holds stays on the cart with `eligible: false` and takes nothing.
  - `DELETE /v1/me/cart/promo` removes all codes; `?code=` removes one (an addition to the scope).
  - Per-section failures exist as scenarios (`store.<section>_error`) and as fixture sets (`commerce.<section>_error`); sections: banners, deals, categories, category_products, featured, cart.
- 2026-11-27: Gates script note. `tool/checks/T-0051-AC5_gates.sh` runs its negative controls on throwaway untracked Bazel packages (removed by a trap and verified), so it never edits a tracked file.


## Outcome
`utility/mc_fixtures_commerce` (archetype UM, pure Dart) is registered in the workspace. It serves the store (banners, deals, categories, a paged category listing, featured) and a per-user cart with three promotion kinds over 9 routes. Products are comics from `mc_fixtures_comics`; bearers are checked with `userForAuthorization`. Money is integer cents throughout. Nine fixture sets (`default`, `empty`, `server_error` and one per failing section) and eight scenarios. `CONTRACT.md` documents the lot.

| AC | Evidence |
|---|---|
| AC1 | `store_test.dart`: `T-0051-AC1` (a 12-request session with writes is byte-identical on two backends; another seed changes prices, not ids; deal end dates follow the fixed clock) |
| AC2 | `store_test.dart` and `fixture_sets_test.dart`: `T-0051-AC2` (each section on its own; each `store.<section>_error` scenario fails only its own routes, probed on all nine; the sets answer the scenarios' bodies; category paging is stable and total for 6 categories at 5 page sizes; the documented stock, deal and featured positions) |
| AC3 | `cart_test.dart` and `money_test.dart`: `T-0051-AC3`. 20 seeded carts (14 on seed 42, 6 on seed 7) are checked after every change against `test/oracle.dart`, which shares no code with the package, and against the invariant "cart total = sum of line totals". The sample is asserted to exercise every promotion kind. Each promotion rule, the stacking order (4 application orders give the same cart) and the half-up per-line rounding are pinned by direct `priceCart` tests and through the API. Integer cents: a response scanner (with negative controls) and a source scan for `double`, rounding calls, decimal literals and division |
| AC4 | `validation_test.dart`: `T-0051-AC4` (every typed code and its reasons, check order, rejected writes change nothing; 401 for 6 kinds of bad bearer on all 4 cart routes, auth before product and body; two users never see each other's cart or codes; the cart persists across requests and clients and `reset()` clears it) |
| AC5 | `provider_contract_test.dart`: `T-0051-AC5` (35 snapshots with the requests that set them up, every route, code, promotion kind and reason covered, manifest and `CONTRACT.md` in step; all 360 product ids resolve on `GET /v1/comics/{id}` with the same title, cover, issue and series for seeds 42 and 7; every image resolves to an existing bundled asset, with a resolver negative control). `tool/checks/T-0051-AC5_gates.sh` (report `documents/evidence/T-0051/engineer/AC5_gates.md`): pure closure with positive and negative controls, registration, fixtures check with controls, commerce tests 6/6 uncached, `test //...` 150/150, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, coverage 377/382 = 98.7 % |

Mutations: `documents/evidence/T-0051/engineer/mutations.sh` (`MC_TASK=T-0051 MC_ROLE=engineer`; refuses a dirty package; formats each mutant, because the Bazel build checks formatting), log `mutations.log`: **95/95 killed**, none survived, none broke the build. Pinned one by one: each buy-2-get-1 rule (order, tie-break, group size, category, eligibility), percent rounding (down, up, on the total) and base, fixed minimum (ignored, exclusive, checked before percent or before everything), sharing and remainder rules, every promotion amount and minimum, the stacking order, line arithmetic, deal pricing, every typed code and status, the check order, auth, per-user and persistence, paging limits, and the section scenarios and sets.

Test integrity: no tests deleted, skipped or weakened; no `// ignore:`. Globs use `MC_GENERATED_DART`. The mutation run also found and fixed one defect in the package: an error `extra` key named `code` overwrote `error.code` (now `promoCode`), see F-0051.

Follow-ups: none. Questions for the PO: none.

## Review round (2026-11-27, Engineer)
1. Overlong product ids: the id pattern is `^(0|[1-9]\d{0,17})$`, so `99999999999999999999` is `404 unknown_product`, not a 500. Test `T-0051-AC4 an overlong or zero-padded product id...`; mutation R1.
2. Leading zeros (`0500060`, `00`) are `404 unknown_product`, echoed as sent. Same test; mutation R2.
3. `mutations.sh` checks `Build did NOT complete` first and counts a test failure only on `FAILED in`. Re-run: **100/100 killed**, 0 survived, 0 broken (95 plus R1 to R5).
4. The category base uses `seriesIdBase`, now exported from `mc_fixtures_comics` (one line in its barrel). Test `T-0051-AC2 a product category follows the comics series id base`; mutation R4.
5. `SectionFailingCommerceDomain` throws an `ArgumentError` listing the valid sections (its constructor is no longer `const`). Test `T-0051-AC2 an unknown section...`; mutation R5.
6. `DELETE .../promo?code=` with a blank value is `400 invalid_parameter` (documented). Test `T-0051-AC4 DELETE promo with a blank code...`; mutation R3.
Gates re-run after merging `origin/main` (already up to date): all PASS, `test //...` 150/150, coverage 98.7 %.

## Merge (TL)
- 2026-11-27: Review-first (ADR-0011). `/code-review` found one important bug: an overlong product id caused a 500. It also found nits on zero-padded ids, `mutations.sh` build detection, `seriesIdBase`, the unknown section and the blank promo code. Review round `eac479e` (100/100 mutations). A single Sonnet Verifier pass gave PASS `6b1ee59` (about 109k tokens; own oracle from `CONTRACT.md`, 8 carts, two real users, 10/10 own mutations, no defects). The TL merged `--no-ff`; on the merge result `check` passed, 150/150 tests, lint was clean, `mc_arch_check` reported OK and no feature or app target reaches the package.
