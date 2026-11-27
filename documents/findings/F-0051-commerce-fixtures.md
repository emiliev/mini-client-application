# F-0051: Commerce fixtures: money in integer cents, stacking promotions, and three traps

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0051)
- **Type:** Gotcha / design record
- **Related:** T-0051, T-0047, F-0015, F-0041, plan 01 U45, P1-09 AC5, P1-21 AC6

## Summary
`mc_fixtures_commerce` is the backend of the DB exemplar. Three things cost time and will recur in the next fixture packages.

1. **`MockResponse.error`'s `extra` is spread after `code`.** The body is `{'code': code, 'message': ..., ...extra}`, so an extra field named `code` silently replaces the error code. A promotion code in `extra: {'code': 'SAVE10'}` turned `unknown_promo` into `error.code == "SAVE10"`. The extra key is now `promoCode`. Never name an extra field `code`, `message`.
2. **The Bazel build checks Dart formatting of `lib/`, so a mutant must be formatted.** A mutation that only changes spacing or line length fails the build (`DartFormat`), which a mutation script counts as "broken", not "killed". `mutations.sh` runs `fvm dart format` on the mutated file before the tests. A second class of broken mutants is analyzer errors from the mutation itself (an unused variable, a dead branch): write the mutant so that every name stays used.
3. **A gates script can run its negative controls without editing a tracked file.** Instead of adding a dependency to a real `BUILD.bazel` (and restoring it), `T-0051-AC5_gates.sh` creates a throwaway untracked package (`utility/zz_negctl_T0051_flutter`, `feature/zz_negctl_T0051/...`) that depends on the package under test, queries its closure, deletes it in a trap and checks the tree is clean. The "Flutter markers appear" control uses a target that depends on the commerce package and on `mc_fixtures_media`.

## Design facts worth reusing
- **Integer money.** Every money field is `...Cents` and an `int`. The one division is `(cents * percent + 50) ~/ 100`. The tests scan every response (a key that names money but does not end in `Cents` fails; a `...Cents` value that is not an `int` fails; the scanner has negative controls) and scan the package source for `double`, `num`, rounding calls, decimal literals, `dart:math` and ` / `.
- **Stacking order by construction.** The pricing is one pure function with a fixed step order (buy-2-get-1, percent, fixed), whatever order the codes were applied in. Tests apply the codes in four orders and require identical carts. A fixed code's minimum is checked against what is left after the first two steps, so adding a percent code can make a fixed code ineligible; it stays on the cart with `eligible: false` and takes nothing.
- **Buy-2-get-1 as a unit ledger.** One entry per unit of the category, sorted by price descending (equal prices: the earlier line), every third entry free. This makes ties deterministic, and the test oracle uses the same rule written as a counter instead of a loop step, so the two are independent implementations of the documented rule.
- **A fixed discount is shared over the lines** by largest remainder (ties: the earlier line), so that every line total is an integer and the cart total is exactly the sum of the line totals.
- **The oracle must not share code.** `test/oracle.dart` repeats the promotion table as literals and computes the percent rounding from the quotient and remainder instead of `+ 50`. The 20-carts test also asserts its sample reached every promotion kind, so it cannot pass vacuously.
- **A dead guard is worse than none.** A cap "fixed amount at most what is left" was unreachable (every minimum is above its amount); no test could kill its mutant, so it was removed and the fact is documented.
- **Per-section failure.** Section scenarios use one `FailureRule` per route (with the route pattern, e.g. `/v1/store/categories/:id/products`); the matching fixture sets override only that section's handlers with the same `serverError` handler, so set and scenario answer byte-identical bodies. A test partitions the nine routes into sections and probes all nine for every scenario.
