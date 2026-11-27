# T-0051: `mc_fixtures_commerce`, the store mock domain (P1-09 subset, U45)

| Field | Value |
|---|---|
| Status | In Progress |
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
