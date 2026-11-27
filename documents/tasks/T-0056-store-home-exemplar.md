# T-0056: `store_home` exemplar (DB archetype), P1-21

| Field | Value |
|---|---|
| Status | In Progress |
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
