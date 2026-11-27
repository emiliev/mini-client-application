#!/bin/bash
# T-0051 engineer mutation checks: each mutation of the commerce package must
# turn at least one test red (a mutation that survives, or that fails to
# build, fails this script). Every promotion rule, the stacking order, the
# rounding, the typed validation codes, auth, per-user carts and the section
# failures are pinned one by one.
#
#   MC_TASK=T-0051 MC_ROLE=engineer documents/evidence/T-0051/engineer/mutations.sh
#
# Refuses to run on a dirty package: every mutation is undone with
# `git checkout -- <package>`, which would also discard uncommitted edits.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2
: "${MC_TASK:?set MC_TASK, e.g. T-0051}"
: "${MC_ROLE:?set MC_ROLE, e.g. engineer}"
P=utility/mc_fixtures_commerce
if [[ -n "$(git status --porcelain "$P")" ]]; then
  echo "refusing to run: $P has uncommitted changes" >&2
  exit 2
fi
OB="/tmp/mc-ob-$MC_TASK-$MC_ROLE"
PR=$P/lib/src/data/pricing.dart
CA=$P/lib/src/data/catalogue.dart
CH=$P/lib/src/handlers/cart_handlers.dart
SH=$P/lib/src/handlers/store_handlers.dart
DOM=$P/lib/src/domain.dart
LOG="$(mktemp -t "mc-$MC_TASK-$MC_ROLE-mut.XXXXXX")"
trap 'git checkout -- "$P"; rm -f "$LOG"' EXIT
killed=0
survived=0
broken=0

run_tests() {
  tool/bazelw --output_base="$OB" test //$P/... > "$LOG" 2>&1
}

# mutate <name> <file> <old> <new>
mutate() {
  local name="$1" file="$2" old="$3" new="$4"
  echo "=== $name"
  if ! python3 -I -c '
import sys
p, old, new = sys.argv[1:4]
s = open(p).read()
if s.count(old) < 1:
    sys.exit("pattern not found: " + old)
open(p, "w").write(s.replace(old, new, 1))
' "$file" "$old" "$new"; then
    echo "    PATTERN NOT FOUND"; broken=$((broken + 1)); git checkout -- "$P"; return
  fi
  # The build checks formatting, so a mutation is formatted like the source.
  fvm dart format "$file" > /dev/null 2>&1
  run_tests
  local failed
  failed="$(tr '\r' '\n' < "$LOG" | grep -aE '^//.*FAILED in' | sed 's/ *FAILED in.*//' | tr '\n' ' ')"
  if tr '\r' '\n' < "$LOG" | grep -aq 'Build did NOT complete'; then
    echo "    BUILD ERROR (does not count as killed)"
    tr '\r' '\n' < "$LOG" | grep -aE 'error|info -|warning' | head -3
    broken=$((broken + 1))
  elif [[ -n "$failed" ]]; then
    echo "    KILLED by: $failed"
    killed=$((killed + 1))
  else
    echo "    SURVIVED"; survived=$((survived + 1))
  fi
  git checkout -- "$P"
}

# Baseline: the unmutated tree must pass.
run_tests || { echo "BASELINE FAILS"; tr '\r' '\n' < "$LOG" | tail -20; exit 1; }
echo "baseline PASS"

# --- buy 2 get 1 ----------------------------------------------------------
mutate "B1 the cheapest unit is taken first (ascending order)" $PR 'a.$1 != b.$1 ? b.$1.compareTo(a.$1)' 'a.$1 != b.$1 ? a.$1.compareTo(b.$1)'
mutate "B2 equal prices go to the later line" $PR ': a.$2.compareTo(b.$2),
    );' ': b.$2.compareTo(a.$2),
    );'
mutate "B3 the first unit of each three is free" $PR 'for (var n = 2; n < units.length; n += 3)' 'for (var n = 0; n < units.length; n += 3)'
mutate "B4 every second unit is free" $PR 'for (var n = 2; n < units.length; n += 3)' 'for (var n = 1; n < units.length; n += 2)'
mutate "B5 a group of four" $PR 'for (var n = 2; n < units.length; n += 3)' 'for (var n = 3; n < units.length; n += 4)'
mutate "B6 every category counts" $PR 'if (lines[i].input.categoryId == p.categoryId) {' 'if (lines[i].input.categoryId == p.categoryId || p.percent == 0) {'
mutate "B7 eligible from two units" $PR 'units.length >= 3)' 'units.length >= 2)'
mutate "B8 HEROES3 is on another category" $PR "'Buy 2 get 1 on Heroes', 'heroes'" "'Buy 2 get 1 on Heroes', 'villains'"
mutate "B9 COSMIC3 is on another category" $PR "'Buy 2 get 1 on Cosmic', 'cosmic'" "'Buy 2 get 1 on Cosmic', 'mystery'"
# --- percent off ----------------------------------------------------------
mutate "P1 percent is taken before buy-2-get-1 (full line)" $PR 'line.subtotalCents - line.buyTwoGetOneCents,
        p.percent,' 'line.subtotalCents,
        p.percent,'
mutate "P2 percent rounds down" $CA '(cents * percent + 50) ~/ 100' '(cents * percent) ~/ 100'
mutate "P3 percent rounds up" $CA '(cents * percent + 50) ~/ 100' '(cents * percent + 99) ~/ 100'
mutate "P4 percent rounds the total, not each line" $PR 'final cut = percentOfHalfUp(
        line.subtotalCents - line.buyTwoGetOneCents,
        p.percent,
      );' 'final cut = identical(line, lines.first)
          ? percentOfHalfUp(
              lines.fold(0, (a, l) => a + l.subtotalCents - l.buyTwoGetOneCents),
              p.percent,
            )
          : 0;'
mutate "P5 SAVE10 is 11 percent" $PR "Promotion.percent('SAVE10', '10% off your order', 10)" "Promotion.percent('SAVE10', '10% off your order', 11)"
mutate "P6 SAVE25 is 24 percent" $PR "Promotion.percent('SAVE25', '25% off your order', 25)" "Promotion.percent('SAVE25', '25% off your order', 24)"
mutate "P7 the fixed step ignores the percent step (stacking order)" $PR 'l.subtotalCents - l.buyTwoGetOneCents - l.percentCents,' 'l.subtotalCents - l.buyTwoGetOneCents,'
# --- fixed off ------------------------------------------------------------
mutate "F1 the minimum is ignored" $PR 'beforeFixed > 0 && beforeFixed >= p.minSubtotalCents' 'beforeFixed > 0'
mutate "F2 the minimum is exclusive" $PR 'beforeFixed >= p.minSubtotalCents' 'beforeFixed > p.minSubtotalCents'
mutate "F3 the minimum is checked on the full subtotal" $PR 'l.subtotalCents - l.buyTwoGetOneCents - l.percentCents,' 'l.subtotalCents,'
mutate "F4 the amount is not shared (all on the first line)" $PR 'lines[i].fixedCents += shares[i];' 'lines[i].fixedCents += i == 0 ? taken : 0;'
mutate "F5 the odd cents go to the smallest remainders" $PR '? remainders[b].compareTo(remainders[a])' '? remainders[a].compareTo(remainders[b])'
mutate "F6 equal remainders go to the later line" $PR ': a.compareTo(b),
        );' ': b.compareTo(a),
        );'
mutate "F7 the odd cents are dropped" $PR 'var left = taken - shares.fold(0, (a, b) => a + b);' 'var left = 0;'
mutate "F8 TAKE5 is worth 400" $PR "500, 2500)" "400, 2500)"
mutate "F9 TAKE5 needs 2400" $PR "500, 2500)" "500, 2400)"
mutate "F10 TAKE15 is worth 1400" $PR "1500, 8000)" "1400, 8000)"
mutate "F11 TAKE15 needs 7000" $PR "1500, 8000)" "1500, 7000)"
# --- lines, deals and totals -----------------------------------------------
mutate "L1 a deal product is charged at list price" $CA 'int get unitPriceCents => deal?.dealPriceCents ?? priceCents;' 'int get unitPriceCents => priceCents;'
mutate "L2 a line ignores its quantity" $PR 'subtotalCents = input.unitCents * input.quantity' 'subtotalCents = input.unitCents'
mutate "L3 a line total drops the fixed discount" $PR 'int get totalCents => subtotalCents - discountCents;' 'int get totalCents => subtotalCents - buyTwoGetOneCents - percentCents;'
mutate "L4 the cart total is the sum of subtotals" $PR 'int get totalCents => lines.fold(0, (a, l) => a + l.totalCents);' 'int get totalCents => lines.fold(0, (a, l) => a + l.subtotalCents);'
mutate "L5 the deal price rounds down" $CA 'price - percentOfHalfUp(price, dealPercents[dealAt]),' 'price - (price * dealPercents[dealAt]) ~/ 100,'
mutate "L6 the first deal is 11 percent" $CA 'const List<int> dealPercents = [10,' 'const List<int> dealPercents = [11,'
mutate "L7 a deal ends a day later" $CA 'endsInDays: dealAt + 1,' 'endsInDays: dealAt + 2,'
mutate "L8 the cart item count is the line count" $CH "'itemCount': priced.itemCount," "'itemCount': priced.lines.length,"
mutate "L9 eligible is always true" $CH "'eligible': r.eligible," "'eligible': true,"
mutate "L10 the list price shows the unit price" $CH "'listPriceCents': line.input.listCents," "'listPriceCents': line.input.unitCents,"
mutate "L11 a set quantity adds to the line" $CH 'cart.quantities[product.id] = quantity;' 'cart.quantities[product.id] = (cart.quantities[product.id] ?? 0) + quantity;'
mutate "L12 quantity 0 keeps the line" $CH 'cart.quantities.remove(product.id);' 'cart.quantities[product.id] = 0;'
mutate "L13 an emptied cart keeps its codes" $CH '// An empty cart carries no codes.
      cart.promotions.clear();' '// An empty cart carries no codes.'
# --- validation, auth, carts ------------------------------------------------
mutate "V1 quantity 100 allowed" $CH 'quantity > maxQuantity)' 'quantity > maxQuantity + 1)'
mutate "V2 quantity -1 allowed" $CH 'quantity < 0 ||' 'quantity < -1 ||'
mutate "V3 the maximum quantity constant is 100" $PR 'const int maxQuantity = 99;' 'const int maxQuantity = 100;'
mutate "V5 stock off by one" $CH 'quantity > product.stock) {' 'quantity >= product.stock) {'
mutate "V6 stock not checked" $CH 'quantity > product.stock) {' 'quantity > product.stock + 1000) {'
mutate "V7 unknown_product answers 400" $CH "404,
  'unknown_product'," "400,
  'unknown_product',"
mutate "V8 out_of_stock answers 400" $CH "409,
      'out_of_stock'," "400,
      'out_of_stock',"
mutate "V9 invalid_quantity answers 422" $CH "400,
  'invalid_quantity'," "422,
  'invalid_quantity',"
mutate "V10 unknown_promo answers 400" $CH "404,
  'unknown_promo'," "400,
  'unknown_promo',"
mutate "V11 promo_not_applicable answers 400" $CH "409,
      'promo_not_applicable'," "400,
      'promo_not_applicable',"
mutate "V12 an id of an unsold comic is a product" $CH 'final product = productId == null ? null : catalogue.byId[productId];' 'final product = productId == null ? null : catalogue.byId[productId] ?? catalogue.products.first;'
mutate "V13 promo codes are case-sensitive" $PR 'raw.trim().toUpperCase()' 'raw.trim()'
mutate "V14 promo codes are not trimmed" $PR 'raw.trim().toUpperCase()' 'raw.toUpperCase()'
mutate "V15 a code already applied is applied twice" $CH 'if (cart.promotions.contains(promo)) {' 'if (cart.promotions.contains(promo) && cart.promotions.length > 100) {'
mutate "V16 two codes of one kind can stack" $CH 'cart.promotions.any((p) => p.kind == promo.kind)' 'cart.promotions.any((p) => p.kind == promo.kind && p.code.isEmpty)'
mutate "V17 a code applies to an empty cart" $CH 'if (cart.quantities.isEmpty) {
    return _notApplicable(promo, '"'empty_cart'"');' 'if (cart.quantities.isEmpty && cart.promotions.length > 100) {
    return _notApplicable(promo, '"'empty_cart'"');'
mutate "V18 buy-2-get-1 applies without a matching item" $CH 'if (promo.kind == PromotionKind.buyTwoGetOne &&' 'if (promo.kind == PromotionKind.buyTwoGetOne && promo.percent > 0 &&'
mutate "V19 fixed-off applies below its minimum" $CH '_price(cart, catalogue).beforeFixedCents < promo.minSubtotalCents' '_price(cart, catalogue).beforeFixedCents < 0'
mutate "V20 fixed-off minimum checked on the subtotal" $CH '_price(cart, catalogue).beforeFixedCents < promo.minSubtotalCents' '_price(cart, catalogue).subtotalCents < promo.minSubtotalCents'
mutate "V21 DELETE with a code removes every code" $CH 'if (raw == null) {' 'if (raw == null || raw.isNotEmpty) {'
mutate "V22 DELETE of a code that is not applied succeeds" $CH 'if (!cart.promotions.remove(promo)) {' 'if (cart.promotions.remove(promo) && cart.promotions.length > 100) {'
mutate "V23 no bearer needed (falls back to the first user)" $CH '  return user == null ? _unauthenticated() : body(user, request, context);' "  return user == null && request.method == 'NOPE'
      ? _unauthenticated()
      : body(user ?? fixtureUsers.first, request, context);"
mutate "V24 the Authorization header is never read" $CH "request.headers['authorization']" "request.headers['x-authorization']"
mutate "V25 unauthenticated answers 403" $CH "401,
  'unauthenticated'," "403,
  'unauthenticated',"
mutate "V26 every user shares one cart" $CH 'return carts.putIfAbsent(userId, Cart.new);' "return carts.putIfAbsent('shared', Cart.new);"
mutate "V27 the empty store shares the default carts" $CH "const String _emptyCartsKey = 'commerce.carts.empty';" "const String _emptyCartsKey = 'commerce.carts';"
mutate "V28 carts do not persist (rebuilt per request)" $CH 'final carts = (context.store[key] ??= <String, Cart>{}) as Map<String, Cart>;' "final carts = (context.store['\$key.\${DateTime.now().microsecondsSinceEpoch}'] ??= <String, Cart>{}) as Map<String, Cart>;"
mutate "R1 an overlong product id throws (int.parse unguarded)" $CH '{0,17})$' '{0,})$'
mutate "R2 leading zeros are accepted" $CH '(0|[1-9]\d{0,17})' '\d{1,17}'
mutate "R3 a blank code on DELETE removes every code" $CH "if (raw != null && raw.trim().isEmpty) {" "if (raw != null && raw.trim().isEmpty && raw.length > 100) {"
mutate "R4 the category base is hard-coded" $CA 'comic.seriesId - seriesIdBase' 'comic.seriesId - 400001'
mutate "R5 an unknown section is not rejected" $DOM 'if (!commerceSections.containsKey(section)) {' 'if (section.isEmpty && !commerceSections.containsKey(section)) {'
mutate "V29 unknown_category answers 200" $SH 'if (catalogue.category(id) == null) {' 'if (catalogue.category(id) == null && id.isEmpty) {'
# --- store sections and paging ---------------------------------------------
mutate "S1 the page limit allows 101" $SH 'const int maxLimit = 100;' 'const int maxLimit = 101;'
mutate "S2 the default page is 25" $SH 'const int defaultLimit = 20;' 'const int defaultLimit = 25;'
mutate "S3 the offset is ignored" $SH 'matches.skip(offset)' 'matches.skip(0)'
mutate "S4 total counts the page" $SH "'total': matches.length," "'total': page.length,"
mutate "S5 a category count is off by one" $SH "'count': catalogue.productsOf(c.id).length," "'count': catalogue.productsOf(c.id).length + 1,"
mutate "S6 the server_error body differs from the scenario" $SH "'injected_failure',
      'Injected HTTP 500" "'server_error',
      'Injected HTTP 500"
mutate "S7 no banner searches" $CA "'target': {'type': 'search', 'query': 'amber'}," "'target': {'type': 'category', 'categoryId': 'mystery'},"
mutate "S8 the store sells four issues per series" $CA 'const int issuesSold = 3;' 'const int issuesSold = 4;'
mutate "S9 the currency is dollars" $CA "const String currencyCode = 'EUR';" "const String currencyCode = 'USD';"
mutate "S10 a deal product can be sold out" $CA 'const List<int> dealPositions = [7,' 'const List<int> dealPositions = [5,'
mutate "S11 five categories" $CA 'categoryDefs.length].id' '5].id'
mutate "S12 a product id is not its comic id" $CA 'id: comic.id,' 'id: comic.id + 1,'
mutate "S13 a product title differs from its comic" $CA 'title: comic.title,' "title: '\${comic.title}!',"
mutate "S14 prices ignore the seed" $CA "final random = SplitMix64(seed).fork('commerce')" "final random = SplitMix64(1).fork('commerce')"
mutate "S15 prices span a different range" $CA '299 + rng.nextInt(1701)' '299 + rng.nextInt(1800)'
mutate "S16 the large stock is below 99" $CA 'const int plentyStock = 120;' 'const int plentyStock = 90;'
mutate "S17 the sold-out products move" $CA 'const int outOfStockRemainder = 5;' 'const int outOfStockRemainder = 6;'
mutate "S18 the deals move" $CA 'const List<int> dealPositions = [7, 48,' 'const List<int> dealPositions = [7, 49,'
mutate "S19 the featured products move" $CA 'const List<int> featuredPositions = [3, 56,' 'const List<int> featuredPositions = [3, 57,'
# --- scenarios and fixture sets ---------------------------------------------
mutate "X1 store.deals_error also fails banners" $DOM "'deals': ['GET /v1/store/deals']," "'deals': ['GET /v1/store/deals', 'GET /v1/store/banners'],"
mutate "X2 a section set fails nothing" $DOM 'for (final route in commerceSections[section]!)' 'for (final route in commerceSections[section]!.skip(1))'
mutate "X3 the server_error scenario misses a route" $DOM 'rules: [for (final route in commerceRouteManifest) _fail(route)],' 'rules: [for (final route in commerceRouteManifest.skip(1)) _fail(route)],'
mutate "X4 the server_error set misses a route" $DOM 'for (final route in commerceRouteManifest) route: store.serverError,' 'for (final route in commerceRouteManifest.skip(1)) route: store.serverError,'
mutate "X5 the empty scenario is the default store" $DOM 'overrides: _handlers(empty: true),' 'overrides: _handlers(empty: false),'
mutate "X6 the empty set is the default store" $DOM '_register(router, _handlers(empty: true));' '_register(router, _handlers(empty: false));'
mutate "X7 injected failures are 503" $DOM 'const FailureKind.http(500),' 'const FailureKind.http(503),'
mutate "X8 the cart section misses a route" $DOM "'POST /v1/me/cart/promo',
    'DELETE /v1/me/cart/promo',
  ]," "'POST /v1/me/cart/promo',
  ],"
echo
echo "killed=$killed survived=$survived broken=$broken"
git status --short "$P"
[[ $survived -eq 0 && $broken -eq 0 ]]
