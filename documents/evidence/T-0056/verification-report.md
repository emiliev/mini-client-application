# Verification report — T-0056: `store_home` exemplar (DB), P1-21

- **Verifier:** crew: Verifier, Opus tier (fresh agent, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0056-store-home` @ `4218950` (detached; it already contains `origin/main` with T-0059)
- **Simulator:** `mc-T-0056-verifier-41316`, iPhone 17 Pro, iOS 26.2. `tool/e2e_ios.sh` created and deleted it (`SIMULATOR_DELETED_AT=1795786986`; `xcrun simctl list devices | grep -c mc-T-0056-verifier` gives `0`). I didn't touch any shared simulator.
- **Bazel:** `/tmp/mc-ob-T-0056-verifier` for the clean worktree (gates, lockfile run, flake check, coverage, mutations, T-0042-AC4). `/tmp/mc-ob-T-0056-verifier-probe` for a second scratch worktree, `/tmp/mc-T-0056-verifier-probe`, which held my probes, the byte-identity re-run and the e2e project. Both servers were shut down, and the scratch worktree was removed.
- **Verdict:** **FAIL.** Two defects have to be fixed before merge, and both fixes are small:
  - **D1 (AC2):** the category page's paging error and Retry have no test at all, although the Outcome lists them. The behaviour works (my probes VP03 and VP04 pass), but the AC requires BDD, and coverage shows that those lines never run.
  - **D2 (AC3):** the review-round cart fix throws `StateError` when the answer arrives after the store has closed.

  Everything else passes on my own runs, including every review item. A Sonnet re-verifier can check the fix round against the checklist at the end of this report.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All gates | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0056-verifier tool/checks/T-0056-AC8_gates.sh --role verifier` | **PASS** on every row: the touched packages uncached, then `test //...` (192/192), `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, the fixtures check, relative API paths, byte identity, cutoff, not committed, gen-l10n parity and coverage ([gates.md](verifier/gates.md)) |
| Lockfile | `test --lockfile_mode=error //...` | **192/192 pass** |
| Byte identity | `T-0056-AC8_matches_build_runner.sh`, run again on its own in the scratch worktree | **20 of 20 EQUAL**: none missing, none extra ([byte_identity.md](verifier/byte_identity.md)) |
| T-0042-AC4 | `tool/ide_sync --env dev` (69 files copied), then `T-0042-AC4_safety.sh`, then `tool/ide_sync --clean` (`git status` clean) | **PASS**: 73,945 outputs had the same bytes, the synced tree ran 0 actions and 0 of 192 tests, and all 4 negative controls fired ([t0042_safety.md](verifier/t0042_safety.md)) |
| Coverage | `bazel coverage` over the 7 packages, then **my own parser** ([vcov.py](verifier/vcov.py.txt)). It starts from the hand-written `lib/` files on disk, so it also lists files that no LCOV mentions | store_home **885/900 = 98.3 %**, commerce_wiring 54/54, app_core 488/502 = 97.2 %, mc_analytics 326/326, mc_feature_flow 172/173, mc_monitoring 29/30, mc_formatters 33/33 ([coverage.txt](verifier/coverage.txt)). These are the same as the gate's numbers. The files that no LCOV mentions are barrels, interfaces, `const` declarations and freezed-only state files. **In store_home, every missed line is on the category page's failure, Retry and refresh paths** (`category_products_bloc.dart` 81, 84, 86, 113; `category_page.dart` 65–68, 88–91): see D1 |
| Flake check | `test --runs_per_test=50 --nocache_test_results` over store_home's 5 targets, `commerce_wiring:routes_test`, mc_analytics `di`, `flow_observer` and `route_observer`, `mc_feature_flow:feature_flow_test`, and mini_client `store_route_test` and `analytics_screens_test` | **12 targets × 50 = 600 runs, 0 failures** ([runs_per_test_50.txt](verifier/runs_per_test_50.txt)) |
| L4 E2E | `tool/e2e/prepare_pub_project.sh`, then `tool/e2e_ios.sh --task T-0056 --role verifier` over **all 16** mini_client targets | **16/16 PASS** ([e2e-summary.md](verifier/e2e-summary.md)). No target log has a build-failure marker, and each store log names its `T-0056-AC5` test |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0056-AC1 | 5 sections in order, both prices from cents, flag off: no featured and no request | BDD "five sections in order", the flag scenarios (off, on, wrong type); `contract_test`; `formatters_test` | **Yes.** The section order comes from the headers in scroll order. The step oracles compute prices from the fixtures' cents (`euros()`, not the app's formatter). With the flag off: 0 `GET /v1/store/featured` requests and 0 views. **Probe VP11:** with the flag off, a Retry and a pull to refresh still send 0 featured requests. Killed: G01. My X10 (the refresh reads the featured bloc while the flag is off) survives the branch's tests and is killed by VP11 (D4) | **PASS** |
| T-0056-AC2 | `server_error`: every section has its own error, each Retry recovers only its own section. `store.empty`. **The category's paging error and Retry** | BDD "every store route fails…", "a double tap on Retry…", "an empty store" | Sections: **yes.** My X01 (the deals Retry also retries the banners) is killed. **Probe VP02** is an outline over all 5 sections: a double Retry sends exactly 1 request and recovers only that section. It passes. The branch tests double Retry only for deals, so X02 (cart) and X03 (featured) survive the branch and are killed by VP02 (D4). **Category paging: no test exists** (D1). My VP03 (page 2 fails, the footer, Retry, 40 products) and VP04 (page 1 fails, the full-page error, Retry) pass on the unmutated code, and X12 survives the branch and is killed by them | **FAIL** (D1) |
| T-0056-AC3 | `openComic` once from a deal, featured and a banner; `openSearch`; the in-flow category and page 2; the cart and the session epoch; wiring | BDD `store_home.feature`, `store_home_cart.feature` (12); `routes_test`; `store_route_test`; `app_layer_test` | **Yes.** Navigator calls are counted in order (`navigatorCalls()`). The 499 and 500 ms guard holds. Page 2 checks `offset=20&limit=20` and 40 products in order. Cart: signed out it awaits `requestSignIn()`, declining keeps it hidden, a double tap asks once, a user switch reloads, a held stale load is dropped, a sign-out during a load works, and **the same-user re-sign-in during a held load ends `ready` with 2 requests and 1 view (review item 1)**. `routes_test` asserts `router.state.uri` for every method and the sheet's reason. Killed: C01, C04, V01, and my X06 and X07. **D2:** VP06 and VP07 fail. When the store closes while a cart read is held and the session then changes, the late answer hits `add` on a closed bloc | **PASS** for the listed behaviours; **D2 must be fixed** in the same round |
| T-0056-AC4 | de strings and money; `en_XA` at 1× and 2×; goldens in 4 themes | BDD `store_home_l10n.feature` (7 scenarios, 2 of them outlines at 1× and 2×); `formatters_test`; 11 goldens | **Yes.** `10,83 €`, `12,03 €` struck through, `Endet in 1 Tag`, `Summe 24,24 €`, `Wird geladen: Angebote`. `nothing overflows` runs over the whole store, the category to its end, and every section failed. **Money probe:** `€0.00` / `0,00 €`, `-€12.99` / `-12,99 €`, `-€0.01` / `-0,01 €`. `Currency.parse` refuses `' EUR'` and `'Eur'`. **I looked at 8 goldens:** light, highContrastDark, failed, empty, loading, lower, pseudo_2x, category_dark. The pseudo-locale at 2× wraps and ellipsizes, and nothing is clipped | **PASS** |
| T-0056-AC5 | The journey, both cold links, the full suite | e2e on my simulator, `store_route_test` | **Yes.** I looked at the store screenshots 41–48c. **41:** the store with highlights, and deals with `€10.83`, `€12.03` struck through and "Ends in 1 day". **42:** categories at "60 comics", featured, and the cart's "Sign in to see your cart." **43:** the comic "Amber Frontier #2". **44:** Back to the store. **46:** Heroes scrolled to "Ember Reckoning #3", the 21st product, which is page 2. **47 / 47b:** the cold `/store`, then Back gives home. **48 / 48b / 48c:** the cold `/store/categories/heroes`, then Back gives the store, then Back gives home | **PASS** |
| T-0056-AC6 | 5 `store.<section>_error` scenarios; a held section blocks nothing; a refresh racing a load ends on the newest answer | BDD `store_home_sections.feature` | **Yes.** The outline covers all 5 scenarios, and each checks that the other 4 are ready. **Probe VP01** holds each of the 5 routes in turn: only that section is loading, the other 4 are ready, there are 0 views until it is released, then 1. All pass. Both race orders are scenarios (`holdNext`). Killed: M01 | **PASS** |
| T-0056-AC7 | The flag and analytics steps with negative controls; viewed once per visit, never when failed, after a Retry; screens `store_home, store_category, store_home` | BDD; `flag_steps_test`; `flags_container_test`; `flow_observer_test` (9); `analytics_screens_test` (+4); `flow_scope_test` | **Yes.** The flag step's negative controls are no step, another key, and a wrong type. **Visibility (review item 2):** a cold category link gives `[0,0,1,0]` store requests (the 1 is the category page's name lookup) and 0 views. Back gives `[1,1,2,1]` requests and 4 views. A comic and Back change nothing. **My probes, all PASS:** a dialog over the store (BDD VP09 and app AP1: no reload, no second view, screens `[home, store_home]`); store → deal → Back (AP2: `…, comics_details, store_home`, no reload); store → category → Back (AP3, and VP10 with two categories in a row: 1 request and 1 view each, screens in order); a `go()` that replaces the store while every section is in flight (AP4: no exception, 0 views); leaving while deals are held (VP08: 0 views). Flow page names `store_home` and `store_category` pass `AnalyticsRules.isValidName` (snake_case, at most `maxNameLength`). Killed: M05, V02, V03, V08, K2, and my X05 and X08 | **PASS** (D3 is a kit limitation for nested flows) |
| T-0056-AC8 | Arch, codegen, coverage, gates, traceability, flake | above | **Yes.** Every scenario in the 4 feature files carries a `@T-0056-ACn` tag (checked by script), and every new test name outside the feature contains its AC id | **PASS** |

## Review round items, checked
1. **Same-user re-sign-in (important).** Fixed: the BDD scenario passes and V01 is killed. **But the fix introduced D2.**
2. **The cold category link loaded and tracked the hidden store (important).** Fixed: proved in the app and in `flow_scope_test`, by my AP1–AP4 and VP08–VP10, and by V02, V03, V08 and X05 being killed.
   - `FlowScope.outerRoute` is read through `getInheritedWidgetOfExactType`, so there is no dependency.
   - `AnalyticsFlowObserver` uses `host:` and not `ModalRoute.of`. The test that the flow navigator lists no `_ModalScopeStatus` dependency is there and passes.
3. **to 7.** Each has its test and its killed mutant in the engineer's log. I re-ran K2 and V08, and both were killed.

## Kit and other changes outside the package
| Package | Justified / tested / minimal? |
|---|---|
| `mc_monitoring` `AnalyticsTracker` | Yes. It is 2 methods and pure Dart. `di_test` proves that the port is the same instance as `Analytics`. The two coverage tests are real |
| `mc_analytics` | Yes. `trackEvent`/`trackScreen` delegate to `track`/`screen`, so validation and the consent gate apply. `AnalyticsFlowObserver` and the route observer's per-route `Expando` records are pinned by `flow_observer_test` (9) and `analytics_screens_test`. The observer's first-page rule depends on the route observer reporting first, which holds because the flow's navigator is built a frame later, behind its container's `FutureBuilder`. It is proved in the app, but nothing in the code makes it true. Worth a comment |
| `mc_feature_flow` | `observers` are read once, which is tested. `outerRoute` and `outerIsCurrent` are tested, and `updateShouldNotify` notifies on a flip (V08 killed). The route-identity term is untested (X11 survives, harmless). **D3:** in a nested flow, `outerIsCurrent` describes the outer flow's page, not the app route |
| `mc_test_utils` | `McTestFlags` is a stub `FeatureFlagsReader` that decodes with the flag's codec (`flags_container_test`). `holdNext` holds once (`harness_test`, U1). `isolation_test` going from 10 to 11 is the one new initializer, **not a weakening**. Nit: the doc comment at `test_container.dart:52` is 127 characters (format does not wrap comments) |
| `mc_test_steps` | The 3 steps are small. The flag step has negative controls |
| `mc_formatters` | `Currency.parse` is exact-match only. The en and de tests check every cent below €100. Fine |
| `app_core`, `commerce_wiring`, `mini_client` | The locations are encoded and checked by drift tests. The commerce domain is in `appMockDomains`. The Store button and its route test are present. Minimal |

## Test-integrity audit
- **Tests deleted, skipped or weakened:**
  - None deleted. No `skip:`.
  - The only `expect` line removed is the `isolation_test` count, which went from 10 to 11 and was declared.
  - No existing `.feature` or golden was modified.
- **Lint suppressions added:** none. No `// ignore:` or `ignore_for_file` is in the diff.
- **Golden files updated:** none existing. There are 11 new ones, and I looked at 8 of them.
- **False claim in the handoff:** the Outcome's AC2 row says "the category's next page failing, then Retry (footer); the first page failing". Neither scenario exists at `4218950`, nor anywhere in the branch's history (`git log -p` over the feature files). See D1.

## Mutations
[My script](verifier/mutations.sh.txt) checks that each restore succeeded, and counts only `FAILED in` as a kill ([log](verifier/mutations.log)). The baseline was green on 8 targets.
- **Re-run from the engineer's 69: 10 of 10 killed:** M01, M05, C01, C04, V01, V02, V03, V08, K2, G01.
- **My own: 12.** On the branch's tests, 5 were killed and 7 survived.
  - **Killed:**
    - X01: the deals Retry also retries the banners
    - X05: the scope always says its route is current
    - X06: every session event reloads, even for the epoch already shown
    - X07: an answer is checked against the shown epoch instead of its own
    - X08: a refresh views every section again
  - **Survived the branch's tests, then killed by my probes (D1, D4):**
    - X02: the cart Retry ignores its state
    - X03: the featured Retry ignores its state
    - X10: a refresh with the flag off reads the featured bloc
    - X12: the category Retry calls `loadMore`
  - **Survived everything (D4, minor):**
    - X04: `ModalRoute.of(context).isCurrent` in the page's start condition is unreachable as false. The store page is always its flow's first and only page when it is built
    - X09: the "read the flag once per visit" decision has no test
    - X11: `!identical(outerRoute, …)` in `updateShouldNotify`

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Category, page 2 | [46_category_page_two.png](verifier/46_category_page_two.png) | "Heroes", scrolled past "Ember Reckoning #3" (the 21st product) to "Ember Station #2", with euro prices | Yes (AC3, AC5) |
| Cold category link | [48_deep_link_category.png](verifier/48_deep_link_category.png) | "Heroes" with a back arrow, and the first products "Ember Chronicles #1" `€14.43` and "#2" `€15.10` | Yes (AC5) |
| Back from the link | [48b_back_from_category_is_store.png](verifier/48b_back_from_category_is_store.png) | The store: highlights, and deals `€10.83` with `€12.03` struck through and "Ends in 1 day" (the same content as the journey's 41) | Yes (AC1, AC5) |
| Back again | [48c_back_from_store_is_home.png](verifier/48c_back_from_store_is_home.png) | Home, with the Store button | Yes (AC5) |

## Issues found
1. **D1 (Major, AC2 FAIL).** The category page's paging error and Retry are untested, although the Outcome says they are tested.
   - There is no scenario for a page-2 failure with the footer Retry, and none for a page-1 failure with the full-page Retry.
   - `category_products_bloc.dart:81` (`_paging.retry()`), `:113` (the failure state) and `category_page.dart:65-68` (the `McErrorView`) never run in any test. The refresh, `category_page.dart:88-91` and `category_products_bloc.dart:84-86`, never runs either.
   - The behaviour itself is correct: VP03 and VP04 pass, and they kill X12.
   - **Fix:** add both scenarios. [VP03 and VP04](verifier/probes/verifier_probe.feature.txt) can be copied as they are; they use only existing steps.
2. **D2 (Medium, the cart and the session; must fix).** `CartSummaryBloc.fetch` adds an event to a closed bloc, at `feature/store/store_home/lib/src/presentation/bloc/cart_summary_bloc.dart:140`.
   - **Repro:** signed in, `the backend holds the next {'GET /v1/me/cart'}`, open the store, the app sends it, leave the store (the flow is disposed), `the session ends elsewhere` (or the same user signs in again), then release.
   - **Result:** `Bad state: Cannot add new events after calling close` from `Bloc.add`, through `fetch` and then `load`. It is thrown out of the handler as an uncaught error, and 2 errors are reported to monitoring (VP06 and VP07 fail; VP05, the control with no session change, passes).
   - In the app this happens whenever the session moves while a cart read is in flight after the user has left the store. For example, the read gets a 401 and the token refresh fails.
   - The DB bricks will copy this "a dropped answer re-adds the session event" pattern.
   - **Fix:** `if (!isClosed) add(const _SessionChanged());`. Pin it with VP06 and VP07.
3. **D3 (Minor, kit and ADR wording).** `FlowScope.outerIsCurrent` and `outerRoute` (`utility/mc_feature_flow/lib/src/feature_flow.dart:328-329`) describe the flow's route **in its outer navigator**.
   - For a flow nested inside another flow's page, that is the outer flow's page route. So when the app route is covered, the inner flow still reads `outerIsCurrent == true`.
   - Probe in `feature_flow_test`: the outer flow reads `false`, the inner one `true`.
   - The same limitation applies to `AnalyticsFlowObserver`: the host's `isCurrent` is the outer flow's, and the route observer never sees the inner record.
   - No flow is nested today. But ADR-0012 §4 says "its flow's route is the app's current route".
   - **Fix (either):** compose with the parent scope in `_FlowScopeHost` (`route.isCurrent && (FlowScope.maybeOf(context)?.outerIsCurrent ?? true)`), or state the limitation in ADR-0012 and in the field's doc.
4. **D4 (Minor, test gaps that surviving mutants expose).** X02 and X03 (only deals tests a double Retry), X10, X04, X09 and X11, described under Mutations.
   - **Suggested:** VP02 (the double-Retry outline) and VP11.
   - Then either remove the unreachable `ModalRoute.of(context)?.isCurrent` term in `store_home_page.dart:91`, or pin it. F-0051: a dead guard is worse than none. Note that removing it also removes that dependency.
5. **D5 (Observation, out of scope).** The comic page for "Amber Frontier #2" shows "Price $3.99" (comics fixtures, USD), while the store sells it at €12.03 / €10.83 (commerce fixtures).
   - The two fixture domains disagree on the product's price and currency.
   - This is not a T-0056 defect. It is a `pending-work.md` candidate for when the comic page and the cart meet (F078).

## ADR-0012 (Proposed): my opinion
**Accept, with two edits.** The code matches the decision:
- the port is in `mc_monitoring` with exactly `trackEvent` and `trackScreen`;
- `Analytics implements` it, and it is registered as the same instance;
- `RootImport<AnalyticsTracker>()` is used;
- the vocabulary is in `store_analytics.dart`;
- `FeatureFlow(observers:)` with `AnalyticsFlowObserver(…, host: FlowScope.read(c).outerRoute)` is used;
- the first-page-equals-route rule is followed;
- flow page names are exempt from the declared-name filter but still pass `isValidName`;
- "a visit is the page's life from its first showing" holds.

Port options B to D are fairly rejected, and A is minimal. The edits:
1. **§4 and the Consequences: the nested-flow limitation (D3).** Say that "shown" means "current in its outer navigator", and that nested flows are not covered until `outerIsCurrent` composes with the parent scope. Or make the kit compose it, and keep the wording.
2. **§3: state the ordering the first-page rule relies on.** The route observer reports the route before the flow observer sees its first page, which holds because the flow builds its navigator after its container's future. Ideally, also add a test that would fail if a flow ever built synchronously. Without it, a future synchronous container would double-track the first page.

## Notes for the Tech Lead
- **Fix round (narrow, Sonnet re-verifier):**
  - **D1:** add VP03 and VP04.
  - **D2:** guard `add` with `isClosed`, and add VP06 and VP07.
  - **Recommended:** VP02 and VP11 (D4). Decide on X04's unreachable term.
  - **Checklist:**
    - the 4 to 6 new scenarios pass;
    - the mutants X12, V01 and "drop the `isClosed` guard" are killed;
    - `T-0056-AC8_gates.sh` passes;
    - a 50-run flake check passes on `bdd_test`.
- My probe files are kept as evidence under [`verifier/probes/`](verifier/probes/) (`.txt`, so nothing builds them), with the diff of the probe edits I made to existing tests.
- Everything else is solid, the review-round fixes above all.
