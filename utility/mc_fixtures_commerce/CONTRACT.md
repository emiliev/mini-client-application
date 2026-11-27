# Commerce contract (`mc_fixtures_commerce`)

Our own domain-first contract (F-0003): the store front (banners, deals, categories, featured products) and the signed-in user's cart with promotions, for the `store_home` exemplar and later commerce features. It claims no compatibility with any real API. Content is invented. Checkout, orders, payments and reviews are out of scope.

The base URL is never contacted: `MockBackend` answers at the Dio transport. Responses are JSON with sorted keys, so equal data is byte-identical. The clock is fixed at `2026-01-01T00:00Z`.

The store sells comics: a **product** is a comic of `mc_fixtures_comics` (read through its public API, `ComicUniverse(seed)`), so `product.id` is a comic id on `GET /v1/comics/:id`, and its `title` and `cover` are what that endpoint serves. Only issues `#1` to `#3` of each series are sold (360 products). The store has its own price in euros and its own stock; the comics' USD price is not used.

## Money

**All money is integer cents.** Every money field is named `...Cents` and is a JSON integer; no field holds a float, and `currency` is `"EUR"` everywhere. A percentage is applied as `cents * percent / 100` in integer arithmetic, **rounded half-up**, and **per line** (never on the cart total): `(cents * percent + 50) ~/ 100`. So 10 % of 495 is 50 (49.5 rounds up), of 705 is 71, of 494 is 49. A test scans every response for a non-integer money value and the package source for any `double`, rounding call or division.

## Routes

| Route | Purpose |
|---|---|
| `GET /v1/store/banners` | The store's banners |
| `GET /v1/store/deals` | Discounted products |
| `GET /v1/store/categories` | The categories |
| `GET /v1/store/categories/:id/products` | One category's products, paged |
| `GET /v1/store/featured` | Featured products |
| `GET /v1/me/cart` | The signed-in user's cart |
| `PUT /v1/me/cart/items/:productId` | Set a line's quantity (0 removes it) |
| `POST /v1/me/cart/promo` | Apply a promotion code |
| `DELETE /v1/me/cart/promo` | Remove the codes (all, or one with `?code=`) |

The machine-readable list is `fixtures/routes.json`; a test keeps it, the domain and this file in step.

The five store routes need no bearer. The four cart routes do (see Auth). Each store route is independent of the others: one failing never changes another (see Scenarios).

### Product

```json
{
  "id": 500060, "title": "Amber Chronicles #1", "categoryId": "heroes",
  "issueNumber": 1, "seriesId": 400003,
  "priceCents": 1443, "dealPriceCents": null, "currency": "EUR", "stock": 36,
  "cover": {"path": "mock-asset://characters/003", "variant": "portrait_large"}
}
```

`dealPriceCents` is `null` unless the product is one of the deals. `stock` is the most a cart can hold of it (0 is sold out).

### `GET /v1/store/banners`

`200` `{"banners": [...]}` with 4 banners (3 to 5 is the contract), each:

```json
{"id": "b-1", "title": "New this week", "subtitle": "Fresh first issues, picked for you",
 "image": {"path": "mock-asset://characters/001", "variant": "landscape"},
 "target": {"type": "comic", "comicId": 500000}}
```

`target` is one of `{"type": "comic", "comicId": <product id>}`, `{"type": "category", "categoryId": <category id>}` or `{"type": "search", "query": "amber"}`. The set has all three kinds. A comic target is a product of the store.

### `GET /v1/store/deals`

`200` `{"deals": [...]}` with 8 deals, each:

```json
{"product": <product>, "originalPriceCents": 1443, "dealPriceCents": 1299,
 "discountPercent": 10, "currency": "EUR", "endsAt": "2026-01-02T00:00:00.000Z"}
```

`dealPriceCents = originalPriceCents - round_half_up(originalPriceCents * discountPercent / 100)`. The percentages are 10, 15, 20, 25, 30, 35, 40, 50 (in that order) and the deals end 1 to 8 days after the fixed clock. A deal product is never out of stock. **The cart charges the deal price** for a deal product.

### `GET /v1/store/categories`

`200` `{"categories": [...]}` with 6 categories (`heroes`, `villains`, `cosmic`, `mystery`, `classics`, `team-ups`), each `{"id", "name", "count", "image"}`; `count` is the number of products of the category (60 each).

### `GET /v1/store/categories/:id/products`

| Query | Type | Default | Rule |
|---|---|---|---|
| `offset` | int | 0 | `>= 0` |
| `limit` | int | 20 | 1 to 100 |

`200` `{"offset", "limit", "total", "count", "results": [<product>, ...]}`. The order is the comics' title order (series title, then issue number), the same on every call, so paging is **stable and total**: the pages of any size, walked until one is empty, return every product of the category exactly once. An offset past the end gives `count: 0` and the same `total`. An unknown category id is `404` `unknown_category` (with `categoryId`). A bad query value is `400` `invalid_parameter` (with `parameter`).

### `GET /v1/store/featured`

`200` `{"products": [<product>, ...]}` with 6 products, all in stock.

## Auth (the cart)

Every cart route needs `Authorization: Bearer <access token>`, checked with `mc_fixtures_identity`'s own `userForAuthorization`. A missing, malformed or expired token, a refresh token used as a bearer, a token of an unknown user or a scheme other than `Bearer` is `401` `unauthenticated`. Auth is checked first: before the product, before the body. A test can mint a token without signing in: `mintAccessToken('u-100', 1)`.

## The cart

The cart belongs to the user the token names, lives in the backend's store and **persists until `reset()`**. Another user's cart is never visible: a request only ever reads and writes its own user's cart. Lines keep the order they were first added in; changing a line's quantity keeps its place. Emptying the cart (removing the last line) also drops its codes.

```json
{
  "currency": "EUR",
  "items": [{"productId": 500120, "title": "Ember Chronicles #1", "cover": {...}, "quantity": 2,
             "listPriceCents": 1443, "unitPriceCents": 1443, "subtotalCents": 2886,
             "discountCents": 1909, "totalCents": 977}],
  "itemCount": 6,
  "promotions": [{"code": "SAVE25", "kind": "percent_off", "title": "25% off your order",
                  "eligible": true, "discountCents": 1722}],
  "subtotalCents": 9836, "discountCents": 5175, "totalCents": 4661
}
```

- `unitPriceCents` is the list price, or the deal price when the product is a deal; `subtotalCents = unitPriceCents * quantity`; `totalCents = subtotalCents - discountCents` of the line, after **all** promotions.
- **The cart's `totalCents` is exactly the sum of the lines' `totalCents`** (P1-09 AC5), and `discountCents` the sum of theirs.
- `promotions` lists the codes in the order they were applied. `discountCents` of a promotion is what it took off in all lines; `eligible` is false when the cart does not (or no longer does) meet its condition, in which case it takes nothing off.

### `GET /v1/me/cart`

`200` the cart (an empty cart is all zeros with empty lists).

### `PUT /v1/me/cart/items/:productId`

Body `{"quantity": int}` with `0 <= quantity <= 99`. Sets the line's quantity (it replaces, it does not add); `0` removes the line (also when it is not there). `200` the cart. Checks, in order: auth, product (`unknown_product`), body shape (`invalid_body`), quantity (`invalid_quantity`), stock (`out_of_stock`). A rejected write changes nothing.

### `POST /v1/me/cart/promo`

Body `{"code": string}`; the code is trimmed and case-insensitive. `200` the cart with the code applied. Checks, in order: auth, body (`invalid_body`), the code is known (`unknown_promo`), then its applicability (`promo_not_applicable`, with a `reason`):

| `reason` | When |
|---|---|
| `already_applied` | This code is already on the cart |
| `kind_already_applied` | A code of the same kind (percent, fixed, buy-2-get-1) is already on it: one of each |
| `empty_cart` | The cart has no lines |
| `no_matching_items` | Buy-2-get-1: no line is in its category (one is enough; it pays off from three units) |
| `minimum_not_met` | Fixed-off: what is left after the earlier steps is below its minimum |

### `DELETE /v1/me/cart/promo`

Removes every code (`200` the cart). With `?code=X` it removes only that one: an unknown code is `404` `unknown_promo`, a code that is not on the cart is `409` `promo_not_applicable` with `reason` `not_applied`.

## Promotions

| Code | Kind | Effect |
|---|---|---|
| `SAVE10` | `percent_off` | 10 % off every line |
| `SAVE25` | `percent_off` | 25 % off every line |
| `TAKE5` | `fixed_off` | 500 cents off, for a subtotal of at least 2,500 |
| `TAKE15` | `fixed_off` | 1,500 cents off, for a subtotal of at least 8,000 |
| `HEROES3` | `buy_2_get_1` | Buy 2 get 1 on the `heroes` category |
| `COSMIC3` | `buy_2_get_1` | Buy 2 get 1 on the `cosmic` category |

## Cart arithmetic and the stacking order

The order is fixed, whatever order the codes were applied in. Each step works on what the earlier ones left.

1. **Line subtotal** = unit price (the deal price if the product has a deal) x quantity.
2. **Buy 2 get 1** (`HEROES3`, `COSMIC3`): take every unit in the code's category, one entry per unit, sorted by unit price descending (equal prices: the earlier line first). Walking that list in groups of three, **the third unit of each group is free** (so the cheapest of its group). The free unit's price is taken off its line. Fewer than three units: nothing is free and the code is not `eligible`.
3. **Percent off** (`SAVE10`, `SAVE25`): for each line, `percent` of what is left of it (subtotal minus step 2), rounded half-up **per line**.
4. **Fixed off** (`TAKE5`, `TAKE15`): applies only if the total left after steps 2 and 3 is at least its minimum (otherwise `eligible` is false and it takes nothing). The amount is shared over the lines in proportion to what is left of each: each line gets `floor(amount * left / totalLeft)`, and the cents that remain go one each to the lines with the largest remainders (ties: the earlier line). The shipped minimums are above their amounts, so a fixed discount never exceeds what is left.

So a percent is worth less after a buy-2-get-1 (the free unit is not discounted again), and a fixed code can stop qualifying after a percent code is added (`TAKE5` on 2,600 is worth 500; with `SAVE25` as well the total left is 1,950, below 2,500, so it takes nothing). Each rule and the order is pinned by a mutation (`documents/evidence/T-0051/engineer/mutations.sh`).

## Validation

| Status | `error.code` | When | Extra fields |
|---|---|---|---|
| 401 | `unauthenticated` | See Auth | |
| 404 | `unknown_category` | A category id that is not one of the six | `categoryId` |
| 400 | `invalid_parameter` | A bad `offset` or `limit` | `parameter` |
| 404 | `unknown_product` | `productId` is not a sold comic (not a number, or issue 4 and up, or any id in the empty store) | `productId` (as sent) |
| 400 | `invalid_body` | The body is not a JSON object; `code` is not a string | `parameter` |
| 400 | `invalid_quantity` | `quantity` missing, not an integer (`1.5`, `"2"`, `true`), or outside 0 to 99 | `parameter`, `min`, `max` |
| 409 | `out_of_stock` | `quantity` is above the stock (a sold-out product has stock 0) | `productId`, `requested`, `available` |
| 404 | `unknown_promo` | The code is not in the table above | `promoCode` |
| 409 | `promo_not_applicable` | See the table under `POST /v1/me/cart/promo` | `promoCode`, `reason` |
| 404 | `not_found` | No mock route (the body names the path) | |
| 500 | `handler_error` | A handler threw | |
| any | `injected_failure` | A `FailureRule` of kind `http(status)`; also the body of the `server_error` and section-failure sets | |

All errors are `{"error": {"code", "message", ...extra}}`.

## Test-facing facts (default set, seed 42)

| Fact | Value |
|---|---|
| Products | 360: issues 1 to 3 of the 120 series, ids as in the comics contract (`500000 + 20n + k - 1`) |
| Categories | A comic is in category `(seriesId - 400000) mod 6` of `heroes`, `villains`, `cosmic`, `mystery`, `classics`, `team-ups` |
| First product in title order | `Amber Chronicles #1` (id `500060`) |
| Deals | The products at positions 7, 48, 89, 130, 171, 212, 253 and 294 of the title-ordered catalogue |
| Featured | The products at positions 3, 56, 109, 162, 215 and 268 |
| Out of stock | Every 11th product from position 5 (positions 5, 16, 27, ...) has stock 0 |
| Plenty | Every 7th product (position 0, 7, 14, ...) has stock 120 (above the 99 maximum); every other product has 3 to 40 |
| Banners | 4: a comic, the `heroes` category, the search `amber`, the `cosmic` category |
| Independent of the seed | Product ids, titles, categories, banners, deal and featured positions and percentages, promotions. Prices (299 to 1,999 cents), the deal prices that follow from them, and the stock of the ordinary products depend on it |

## Scenarios

| Name | Effect |
|---|---|
| `commerce.empty` | An empty store: no banners, deals, categories or featured (empty lists), every category is `unknown_category`, no product can be added (`unknown_product`), the cart is always empty. Auth and validation are unchanged. It has its own carts, so switching it off never leaves a line that names a missing product |
| `commerce.server_error` | Every route fails with `500` (`injected_failure`) |
| `store.banners_error` | Only `GET /v1/store/banners` fails with `500` |
| `store.deals_error` | Only `GET /v1/store/deals` fails with `500` |
| `store.categories_error` | Only `GET /v1/store/categories` fails with `500` |
| `store.category_products_error` | Only `GET /v1/store/categories/:id/products` fails with `500` |
| `store.featured_error` | Only `GET /v1/store/featured` fails with `500` |
| `store.cart_error` | The four cart routes fail with `500` |

A section failure leaves every other route as it was (P1-21 AC6: only that section shows an error and the others render).

## Fixture sets

Named sets for feature tests (plan 05 §3.4), exported as `commerceFixtureSets`. A test registers them once (`commerceFixtureSets.forEach(McFixtureSets.register)`) and switches one on per scenario. Each set serves all nine routes. The set and the scenario of the same name answer the same bodies, as the sections above (the section sets are `commerce.<section>_error` and the scenarios `store.<section>_error`). A set is meant to be served with the comics set its products link to, and the identity set that issues the token.

| Set | Cast | Test-facing facts |
|---|---|---|
| `commerce.default` | `CommerceMockDomain` | See the table above |
| `commerce.empty` | `EmptyCommerceDomain` | as the `commerce.empty` scenario; no scenarios |
| `commerce.server_error` | `FailingCommerceDomain` | all nine routes answer `500` with `error.code` `injected_failure`; no scenarios |
| `commerce.banners_error` | `SectionFailingCommerceDomain('banners')` | only `GET /v1/store/banners` answers `500` |
| `commerce.deals_error` | `SectionFailingCommerceDomain('deals')` | only `GET /v1/store/deals` answers `500` |
| `commerce.categories_error` | `SectionFailingCommerceDomain('categories')` | only `GET /v1/store/categories` answers `500` |
| `commerce.category_products_error` | `SectionFailingCommerceDomain('category_products')` | only `GET /v1/store/categories/:id/products` answers `500` |
| `commerce.featured_error` | `SectionFailingCommerceDomain('featured')` | only `GET /v1/store/featured` answers `500` |
| `commerce.cart_error` | `SectionFailingCommerceDomain('cart')` | the four cart routes answer `500` |

## Snapshots

`test/contract/snapshots/*.json` pin one request each (`request`, `setup` (the requests made before it, as the same user), `requestBody`, `status`, `body`), run on a fresh default backend. A diff there is a contract change: regenerate with `fvm dart run utility/mc_fixtures_commerce/tool/update_snapshots.dart`, review it, and update this file.
