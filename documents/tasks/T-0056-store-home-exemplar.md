# T-0056: `store_home` exemplar (DB archetype), P1-21

| Field | Value |
|---|---|
| Status | In Verification (engineer handoff) |
| Owner | crew: Engineer (**Opus**: first DB exemplar, which the bricks copy; ADR-0011) |
| Verifier | crew: Verifier, **Opus tier** (exemplar) |
| Branch | `fleet/T-0056-store-home` |
| Created | 2026-11-27 |
| Depends on | T-0051 (`mc_fixtures_commerce`), T-0052 (`mc_feature_flags`), T-0053 (`mc_analytics`), T-0030/T-0031 (`mc_paging`, DS lists and media), T-0040 (DS navigation), T-0049 (`nestUnderHome`) |
| Related | plan 01 F077, P1-21 (EX-AC1–5 plus AC6), §3.3, §4, §6.1 (DB: 2 pages, 5 blocs, one per section, 5 endpoints, 6 nav methods); ADR-0007, ADR-0010, ADR-0011; R4, R6, R15–R17, R30; F-0031, F-0040, F-0046, F-0048, F-0051, F-0052, F-0053; P-103, P-107 |

## Goal
This is the fifth archetype exemplar, **dashboard (DB)**: `feature/store/store_home`. The store front has independent sections: banners, deals, categories, featured, and a cart summary. Each section loads, fails and retries **on its own**. A category opens a paged product list inside the flow. Tapping a product opens the comic.

As with T-0032, T-0041, T-0046 and T-0048, this package is the shape the P1-24 bricks copy for every DB feature (`insights_reading_stats`, `system_status`, …). It must match the established exemplar shapes, with no workarounds. It is also the **first feature to use `mc_feature_flags` and `mc_analytics`**, so it sets the pattern for both.

## Scope
- **In: `feature/store/store_home`**
  - **Flow and navigator.**
    - `StoreHomeFlow` has 2 flow pages: the store home and a category's products.
    - `StoreHomeNavigator` has:
      - `openComic(ComicId)`, for a product, a deal or a banner that targets a comic;
      - `openSearch(String query)`, for a banner that targets the search query;
      - `openCart()`, a placeholder target for now;
      - `requestSignIn()`, for the cart summary when signed out (the SC pattern, awaited).

      That is four methods; the archetype's 6 are reached as the features grow. Document which are deferred.
    - A banner that targets a category opens the category page inside the flow.
  - **API and repository.**
    - One retrofit API covers the 5 section endpoints plus category products: `GET v1/store/banners`, `deals`, `categories`, `categories/{id}/products` and `featured`, and `GET v1/me/cart` (summary only: item count and total).
    - The repository is stateless.
  - **State: one bloc per section** (5 blocs), each with a freezed sealed state: `loading`, `ready`, `empty` and `failure`.
    - A section's failure never affects another section. Retry is per section.
    - Pull-to-refresh reloads all sections in parallel.
    - The cart section is hidden when signed out. It reloads on the session epoch, using the check-after-await rule.
  - **Category page.** It uses the `mc_paging` paged list (offset and limit) with `McMediaCard`.
  - **Money.**
    - Format integer cents with `mc_formatters`. If there is no money formatter yet, add one there with tests in en and de: €12.99 in en, 12,99 € in de.
    - Never use `double` for money in the feature.
    - Deals show the original price struck through, the deal price, and "ends in" against the fixtures' fixed clock, injected.
  - **Feature flag (first use).**
    - A `const FeatureFlag<bool> storeHomeFeatured` is declared in the feature. When it is false, the featured section is not built and its endpoint is not called.
    - Resolve P-107: `McTestContainer` registers flags with a stub snapshot, so BDD can set flag values with a new generic step: `the flag {key} is {value}`.
  - **Analytics (first use).**
    - Track `store_section_viewed` once per section per visit, with `section` as a parameter, when the section reaches `ready`.
    - Track `store_item_tapped` with `section`, `kind` and `id`. Use the T-0053 BDD steps.
    - The page names are `store_home` and `store_category`. Resolve P-103 for this feature by tracking the category page as `store_category` from inside the flow. Use the smallest general mechanism `mc_analytics` or `mc_feature_flow` allows, and document it so bricks copy it.
  - **UI.**
    - `McAppBar` with `McFlowBackButton`, then `McSectionHeader` for each section, a horizontal carousel for banners and deals, and a grid for categories.
    - Each section has its own error card with Retry, and its own skeleton loader.
  - **Tests and strings.**
    - l10n in en and de.
    - BDD, contract tests and goldens. No solitary unit tests (R6), except the money formatter in `mc_formatters`.
- **In: `app/wiring/commerce_wiring`**
  - The `/store` route, nested under home via `nestUnderHome`, and `/store/categories/:id`, which opens the flow at that category.
  - `CommerceRouteTargets`.
  - The navigator implementation: comics via `AppLocations`, search via `AppLocations.search(q)`, and sign-in as in `comics_details`.
  - `AppLocations.store()` and `AppLocations.storeCategory(id)`, plus the drift test.
- **In: `mini_client`**
  - A Store entry on home.
  - Deep links `miniclient://app/store` and `miniclient://app/store/categories/<id>`.
  - Add the commerce mock domain to `appMockDomains`.
- **Out:**
  - checkout and the cart screen (a placeholder target)
  - promo entry
  - the `commerce_sandbox` (record it in the Outcome as a follow-up, as P-091 did for the library sandbox)
  - experiments and exposure events (P-102)

## Acceptance criteria
- **T-0056-AC1 (EX-AC1).** Given `store.default`, when I open the store, then all 5 sections render in order with the fixtures' content. Deals show both prices formatted from cents. With the flag off, featured is absent and `GET v1/store/featured` is never called. BDD.
- **T-0056-AC2 (EX-AC2).**
  - Given `server_error`, every section shows its own error with Retry, and each Retry recovers only its own section.
  - Given `store.empty`, the empty states show.
  - The category page's paging error and Retry work.
  - BDD.
- **T-0056-AC3 (EX-AC3).**
  - Tapping a deal, a featured product or a comic banner calls `openComic(id)` exactly once.
  - A search banner calls `openSearch(q)`.
  - A category opens the in-flow category page, and the next page loads at the end of the list.
  - Signed out, the cart summary awaits `requestSignIn()`. On `true`, the cart section appears for that user. A user switch reloads it, and a stale load is dropped.
  - The wiring test pushes the right location for each method.
  - BDD plus a wiring test.
- **T-0056-AC4 (EX-AC4).**
  - Given locale `de`, all strings and money are German.
  - Given `en_XA`, nothing overflows at 1× and 2× text scale. Use goldens across the 4 themes, as the earlier exemplars do.
- **T-0056-AC5 (EX-AC5).** The mini_client e2e and the deep links, with screenshots:
  - home → Store → sections → a deal → the comic page → Back to the store → a category → scroll to page 2;
  - `miniclient://app/store` cold;
  - `miniclient://app/store/categories/<id>` cold. Back walks the nested path to home.
  - Check every target log for build failures until T-0055 lands.
- **T-0056-AC6 (P1-21 AC6).**
  - Given `store.deals_error`, only the deals section shows an error, and the other 4 sections render. Repeat this for every section's failure scenario: 5 BDD scenarios, one per `store.<section>_error`.
  - A slow section (a held response) never blocks the others from rendering.
  - Pull-to-refresh while one section is in flight ends with each section on its newest answer.
  - Run it under fake time with held responses through `McBackendHarness`.
- **T-0056-AC7 (flags and analytics).**
  - The flag step and the analytics steps are used and proved with negative controls.
  - `store_section_viewed` fires exactly once per section per visit, and not for a failed section. It fires after Retry succeeds.
  - Screen names are tracked in exact order for store → category → back: `store_home`, `store_category`, `store_home`.
- **T-0056-AC8 (architecture, codegen and gates).**
  - Architecture and codegen: `mc_arch_check` passes. The barrel exports only the flow, the navigator and arg types. Nothing generated is committed, and output is byte-identical to build_runner's. The cutoff and fixtures checks pass. Globs use `MC_GENERATED_DART`, and `T-0042-AC4_safety.sh` passes after `tool/ide_sync`.
  - Package coverage is ≥ 90 %. `test --lockfile_mode=error //...`, lint, `rules_fork.sh check`, format and `l10n_check` pass. Everything is traceable by `T-0056-ACn`.
  - The 50-run flake check passes on every new test target.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Opus). Kit support first (the `AnalyticsTracker` port, flow screen tracking, stub flags, `holdNext`, `Currency.parse`), then the feature, the wiring, the app entry and the links. A usage-limit pause mid-task; resumed from the WIP commit, with the tree and the simulators checked clean.
- 2026-11-27: BDD 59 scenarios green; 11 goldens; e2e 3/3 on `mc-T-0056-engineer-*` (deleted); mutations 57/57 killed; `origin/main` (T-0054) merged, with 2 "both sides added" conflicts in `app/mini_client` resolved by keeping both; gates PASS on the merge result; 50-run flake check. Handed off.

## Outcome
**Handed off** for review and verification on `fleet/T-0056-store-home`. Finding: [F-0056](../findings/F-0056-dashboard-exemplar.md) (the rules the DB bricks copy). Evidence: [`documents/evidence/T-0056/engineer/`](../evidence/T-0056/engineer/).

### What was built
- **`feature/store/store_home`** (DB), in plan 01 §3.3's layout and the earlier exemplars' shapes:
  - **Barrel:** `StoreHomeFlow`, `StoreHomeNavigator`, `ComicId`, `CategoryId` (R4).
  - **Navigator (4 of the archetype's 6):** `openComic`, `openSearch`, `openCart` (a placeholder route), `requestSignIn`. Deferred: `openCheckout()` (with F078) and `openPromo(code)`.
  - **Flow:** `StoreHomeFlow(navigator:, clock:, initialCategory:)`, keyed by the category. Its pages are `store_home` and `store_category` (their screen names). Opened at a category, the category page is the only page, so Back walks category → store → home.
  - **Data:** one retrofit `StoreHomeApi` (relative paths): `GET v1/store/banners`, `deals`, `categories`, `categories/{id}/products`, `featured`, and `v1/me/cart` (the summary, pinned to its session epoch). Ten DTOs, all `@Freezed(fromJson: true, toJson: true)` (R30), integer cents only. A stateless repository.
  - **Blocs (6):** one per section (banners, deals, categories, featured, cart) on a pure-Dart base, `StoreSectionBloc` (load, refresh, the newest answer wins by generation, `store_section_viewed` once per visit, the open guard), plus the category page's `PagingController` bloc. Each has its own sealed events and freezed state.
  - **Pages:** the store home (`McAppBar` + `McFlowBackButton`, `McSectionHeader` per section, carousels for banners, deals and featured, an adaptive grid for categories; each section has its own skeleton, error card with Retry, and empty line; iOS pull to refresh) and the category page (`McPagedGrid` of `McMediaCard`, the paging error and Retry in the footer, not-found).
  - **Flag:** `storeHomeFeatured` (`store.home_featured`, default on), read once by the page; when it is off, the featured section and its bloc are never built.
  - **Analytics:** `store_section_viewed` (`section`), `store_item_tapped` (`section`, `kind`, `id`), and the screens `store_home` and `store_category` from inside the flow.
  - **l10n:** en, de and `en_XA` (35 keys).
  - **Tests (R6):** 4 `.feature` files (59 scenarios with the outlines' examples), `contract_test` (13), `flow_scope_test` (6), `golden_test` (11 goldens), `architecture_test` (4, including no floating-point money).
- **`app/wiring/commerce_wiring`** (was a skeleton): `store_routes.dart` (`StoreRoute` `/store` `store_home`, with children `StoreCategoryRoute` `categories/:id` `store_category` and `StoreCartRoute` `cart` `store_cart`), `CommerceRouteTargets` + impl, `CartPlaceholderFlow`, `StoreHomeNavigatorImpl` (`@LazySingleton`; comics and search via `AppLocations`, the cart by its typed route, sign-in by the shared fixture sheet with "to see your cart"), `CommerceWiringDIInitializer` (the backend's clock via `commerceClock`), `routes_test` (13).
- **`app/wiring/app_core`:** `AppLocations.store` and `AppLocations.storeCategory(id)` (encoded); `CommerceMockDomain` in `appMockDomains`; two `app_layer_test` cases.
- **`app/mini_client`:** a Store entry on home; `store_route_test` (6: the entry, a deal → comic → Back, a search banner, both cold links and their back stacks, a category inside the flow); `analytics_screens_test` gains the store routes and 3 screen-order tests; e2e `store_journey_test`, `store_deeplink_test`, `store_category_deeplink_test`.

### AC → evidence
| AC | Tests and evidence |
|---|---|
| AC1 | `:bdd_test` "Signed in, the five sections show the store in order" (the section order; every banner; every deal with both prices, struck through and not, and "ends in"; every category with its count; every featured comic with its price; the cart's count and total as the backend engine holds them; one request per section; the cart's bearer); signed out (no cart request); the flag off, on (control) and of the wrong type. `:contract_test` the mapper keeps integer cents, days left; `:flow_scope_test` the injected clock; `:architecture_test` no floating point; `mc_formatters:formatters_test` en `€12.99`, every cent below €100, `Currency.parse`; golden of the lower sections |
| AC2 | `:bdd_test` "When every store route fails, each section shows its own error and each Retry recovers only its own section" (request counts per section); a double Retry loads once; the empty store (`commerce.empty`); the category's next page failing, then Retry (footer); the first page failing. Goldens: failed, empty |
| AC3 | `:bdd_test`: a deal, a featured comic and a comic banner each call `openComic` exactly once; the 499/500 ms guard; two deals in one frame open both; a search banner calls `openSearch('amber')`; a category banner opens the category, named by lookup; a category opens in the flow and page 2 loads at the end (`offset=20&limit=20`); Back keeps the sections; View cart. `store_home_cart.feature` (11): signed out awaits `requestSignIn()`; declined; a double tap; a user switch reloads; a stale load is dropped (held); a sign-out while loading; a switch right before the read is sent (pinned, no error reported); a sign-in elsewhere during the store's own sign-in; failure and Retry; refresh while signed out. `commerce_wiring:routes_test` pushes the right location for every method, the sheet's reason, the drift table; `mini_client:store_route_test` |
| AC4 | `:bdd_test`: German sections, deal prices (`10,83 €`, `Endet in 1 Tag`), cart (`Summe 24,24 €`), errors and the category page; `en_XA` at 1x and 2x over the whole store, the category page to its end, and every section failed: `nothing overflows`. `mc_formatters` de `12,99 €`. Goldens: the store home in all 4 themes, the category page light and dark, the pseudo-locale at 2x. `l10n_check:workspace_gate_test` |
| AC5 | e2e on a fresh `mc-T-0056-engineer-*` (iOS 26.2, deleted), [summary](../evidence/T-0056/engineer/e2e/e2e-summary.md): `store_journey_test` 40–46 (home → Store → sections → a deal → the comic page → Back → Heroes in the flow → page 2), `store_deeplink_test` 47 (`miniclient://app/store` cold, Back home), `store_category_deeplink_test` 48 (`…/store/categories/heroes` cold, Back → store → home). No build-failure marker in any target log. Also `mini_client:store_route_test` and `commerce_wiring:routes_test` |
| AC6 | `store_home_sections.feature`: the outline over `store.banners_error` … `store.cart_error` (5); every request leaves at once; a held section never blocks the other four; a refresh racing an in-flight load ends on the newest answer in both orders (`the backend holds the next`); pull to refresh reloads all in parallel and keeps what is shown. Golden: loading |
| AC7 | Flag step: `the flag {key} is {value}` in 3 scenarios, plus `mc_test_steps:flag_steps_test` (negative controls) and `mc_test_utils:flags_container_test`. Analytics: `the section {s} was viewed {n} times` (once per visit, 0 when failed, 1 after Retry, not again after a refresh or Back from the category); the T-0053 `was tracked with` table and an outline over every kind of tap; `the screens tracked are {'store_home, store_category, store_home'}`; in the app, home → store → category → back → back, and category → comic → back (`mini_client:analytics_screens_test`); `mc_analytics:flow_observer_test` (6) and `di_test` (the port) |
| AC8 | [`T-0056-AC8_gates.md`](../evidence/T-0056/engineer/T-0056-AC8_gates.md) **PASS** on the merge with `origin/main`: tests 188/188, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixtures check, relative paths; [byte identity, 20 of 20 EQUAL](../evidence/T-0056/engineer/T-0056-AC8_matches_build_runner.md), [cutoff](../evidence/T-0056/engineer/T-0056-AC8_cutoff.md), [not committed](../evidence/T-0056/engineer/T-0056-AC8_generated_not_committed.md), [gen-l10n parity](../evidence/T-0056/engineer/T-0056-AC8_gen_l10n_parity.md); [`test --lockfile_mode=error //...`](../evidence/T-0056/engineer/T-0056-AC8_lockfile_test.txt) 188/188; [50-run flake check](../evidence/T-0056/engineer/runs_per_test_50.md); `T-0042-AC4_safety.sh` after `tool/ide_sync` ([report](../evidence/T-0056/engineer/T-0042-AC4_safety.md)); `:architecture_test` (the barrel, R15) |

### Coverage (AC8)
store_home 867/882 = 98.3 %, commerce_wiring 54/54 = 100 %, app_core 484/502 = 96.4 %, mc_analytics 319/319 = 100 %, mc_feature_flow 168/169 = 99.4 %, mc_monitoring 29/30 = 96.7 % (it was 73.3 %, a pre-existing gap that two tests close), mc_formatters 33/33 = 100 %.

### Mutations
[mutations.sh](../evidence/T-0056/engineer/mutations.sh) (`MC_TASK=T-0056 MC_ROLE=engineer`; it refuses a dirty tree, sets its restore trap before any edit, counts `Build did NOT complete` as BROKEN and only `FAILED in` as a kill): **57 of 57 killed**, none broken and none timed out ([log](../evidence/T-0056/engineer/mutations.log)). They cover the section mechanics (9), the section blocs (9), the cart's session rules (7), the category page (4), the page and flow (4), the data and money mapping (6), the wiring (6), the money formatter (4), the kit (6: flow screens, the port, `FeatureFlow.observers`) and the test kit (2). Two cart guards that no mutant could kill (an invalidate on sign-out behind the epoch check, and a ready-state check before opening the cart) were removed rather than kept as dead code.

### Edits outside `feature/store/store_home` and `commerce_wiring` (TL, please confirm)
- `utility/mc_monitoring`: `AnalyticsTracker`, the pure-Dart port (blocs cannot import the Flutter package `mc_analytics`, R15), and two tests that close the package's coverage gap.
- `utility/mc_analytics`: `Analytics implements AnalyticsTracker`, registered by `AnalyticsDIInitializer`; `AnalyticsFlowObserver`, and the route observer reading a flow's page (P-103); README; tests `flow_observer_test` and `di_test` (+2).
- `utility/mc_feature_flow`: `FeatureFlow(observers:)` (read once) and a test (P-103).
- `utility/mc_test_utils`: `McTestFlags`, registered by `McTestContainer` as `FeatureFlagsReader` (P-107); `McBackendHarness.holdNext`; tests. `isolation_test`'s initializer count goes from 10 to 11 (the new entry; not a weakening).
- `utility/mc_test_steps`: `the flag {key} is {value}`, `the backend holds the next {route}`, `the backend runs the scenario {name}`; `flag_steps_test`.
- `utility/mc_formatters`: `Currency.parse`; en and de money tests.
- `app/wiring/app_core`: the two locations, the commerce domain, `app_layer_test` (+2).
- `app/mini_client`: the Store button and its callback; `store_route_test`; `analytics_screens_test` (the route-name set plus 3 tests); 3 e2e targets; BUILD.
- `tool/l10n_check` (gate data and a test), `tool/checks/T-0056-AC8_*.sh`, and the root `pubspec.yaml` (the workspace member; `pubspec.lock` and `MODULE.bazel.lock` are unchanged).

### Decisions made inside the scope
1. **Blocs track analytics through a port in `mc_monitoring`**, rather than a feature-local adapter or a split of `mc_analytics`: one general mechanism that every brick reuses, and neither kit gains a dependency.
2. **In-flow screens:** a generic `FeatureFlow(observers:)` plus `AnalyticsFlowObserver` in `mc_analytics`, so `mc_feature_flow` stays free of analytics. A flow's first page shares its route's name.
3. **The page reads the flag once per visit**, not a bloc: a section that is off has no bloc at all.
4. **One base class holds the section mechanics**, and each section keeps its own events and freezed state (the archetype's "one freezed state per section").
5. **A category is a flow page.** `/store/categories/:id` opens the flow with the category as its only page. When the opener did not know the category's name, the page looks it up.
6. **Signed out, the cart summary is hidden but the section stays**, offering to sign in (the only way to reach `requestSignIn()`). The session, not the sheet's answer, decides what shows next.
7. **The deals' clock is a flow argument** (`clock:`), provided as `StoreClock`; the wiring passes the mocked backend's clock.
8. **Six blocs, not five:** the category page needs its own paging bloc.

### Test integrity
No test was deleted, skipped or weakened, and there is no `// ignore:`. Two existing tests changed: `mc_test_utils:isolation_test` (the initializer count, 10 → 11) and `mini_client:analytics_screens_test` (three new route names, merged with T-0054's `not_found`). Goldens: 11 new, all looked at; no existing golden changed.

### Follow-ups (for `pending-work.md`)
- `app/sandbox/commerce_sandbox` (P1-21 lists it; out of this task's scope), as P-091 did for the library sandbox.
- `openCheckout`, `openPromo` and the cart screen, with checkout (F078).
- `mcgen wire` for `flow_scope.dart`.
- `AnalyticsFlowObserver` misses an inner page change made while a dialog covers the route (no screen does that today).
- Other features' in-flow pages (the characters preview, the wizard steps) could adopt `AnalyticsFlowObserver`; their page names are not screen names yet.
