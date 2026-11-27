# F-0056: The dashboard exemplar: section blocs, per-section retry, the first flag and analytics, and money

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0056)
- **Type:** Design record / Lesson / Kit gap
- **Related:** T-0056, ADR-0012 (proposed), P1-21, plan 01 §3.3, §6.1, R15, R17, R30; F-0031, F-0040, F-0046, F-0048, F-0051, F-0052, F-0053; P-103, P-107

## Summary
`store_home` is the fifth exemplar (DB): the store front in five independent sections (banners, deals, categories, featured, cart) and a paged category page inside the flow. It is the first feature to read a feature flag and to track analytics, so it sets both patterns. **No codegen shim failed on a real-world case**: the 20 freezed, json, retrofit and injectable outputs equal build_runner's (`T-0056-AC8_matches_build_runner.md`). The DB bricks copy sections 1 to 6; section 7 lists the traps.

## 1. One bloc per section, one base for the mechanics
Each section has its own bloc, its own sealed events (Tide's private cases) and its own freezed state with `loading`, `ready`, `empty` and `failure` (the cart adds `signedOut` and `signingIn`). The mechanics every section shares live in one pure-Dart base, `StoreSectionBloc<E, S, T>` (`presentation/bloc/store_section_bloc.dart`); a section implements `fetch()`, `isEmptyData()` and the four state factories, and dispatches its own events to `load`, `refresh` and its taps.

- **Independence is structural.** A section's request, state and error card belong to it alone: one failing, slow or empty section cannot blank another. Proved per section with `store.<section>_error` (a Scenario Outline of 5), a held section while the other four render, and `commerce.server_error` with one Retry at a time.
- **The newest answer wins.** Every load bumps a generation; an answer is written only if no load started after it (F-0046 fact 7). Both race orders are scenarios: a refresh's success beats an older load that fails later, and a refresh's failure beats an older load that succeeds later (`the backend holds the next {route}`, section 7).
- **Retry is per section**, and only from `failure`: a second tap finds the section loading, so a double tap sends one request.
- **Pull to refresh reloads every section at once.** The page adds `refresh(done)` to each bloc and waits for all; a refresh keeps the shown state until its answer lands.
- **Every section starts when the visit starts.** A lazy provider below the fold is never read until the user scrolls (the list is lazy, F-0040 fact 6), so the page's start reads every bloc itself and adds its `load` (the first handoff used `BlocProvider(lazy: false)`; with the explicit start that became dead code, and its mutant survived, so it was removed). Pinned by "Every section sends its request when the store opens, before any scrolling".
- **A visit starts when the page is shown (review round).** The blocs are idle until the page adds `load`, which it does the first time it is *shown*: `FlowScope.outerIsCurrent` (new) is true, meaning that the flow's own route is current in its navigator and, for a nested flow, the flow around it is visible too (Verifier round: `FeatureFlow` composes the two, so the word means "this flow page is visible in the app" at any depth). The first handoff also checked `ModalRoute.of(context).isCurrent` for the flow page itself; the store page is always its flow's first page when it is built (the category page only ever opens above it), so that term could never be false and was removed in the Verifier round. go_router builds the store page under a cold `/store/categories/:id` link, and the first handoff loaded and tracked all five sections there. **A visit** is the page's life, from that first showing to its disposal: a comic opened and closed over the store is the same visit, so nothing loads or is viewed again. Pinned by `flow_scope_test` (a page built under a cover loads nothing; once uncovered, one request and one view per section; covered again, no change) and `mini_client:analytics_screens_test` (the cold category link, then Back, then a comic and Back).
- **The open guard** (500 ms, the other exemplars' value) is in the base; a different item goes through at once, a second category tap while the first page slides in keeps the first.

## 2. The session-dependent section (the cart)
- Signed out, the summary is hidden and the section offers to sign in; a tap awaits `requestSignIn()`. **The session, not the answer, decides** what shows next: a sign-in elsewhere while the store waits is just as good.
- The section listens to `SessionReader.authState` and reloads once per epoch (`_shownEpoch`; not before the visit started).
- **A dropped answer reloads (review round).** A sign-in as the same user starts a new epoch with no `authState` event (F-0052 decision 3), so the first handoff dropped the answer and stayed on its skeleton. Now `fetch()`, on finding the epoch moved, adds the session event itself, and the section reloads for the epoch now current. Pinned by "A same-user re-sign-in while the cart is loading ends on that user's cart". (`SessionEpochs.epochChanges` would also have worked; the drop-reload covers every missed event, needs no cast to `SessionEpochs`, and one mechanism keeps both mutants killable.)
- **Never `add` after an await without `isClosed` (Verifier round).** The drop-reload above adds `_SessionChanged` after the request's await; if the store was left meanwhile, the bloc is closed and `add` throws `StateError` (an uncaught error in the zone). The add is now `if (!isClosed) add(...)`. Pinned by the three "Leaving the store while the cart loads, …: nothing fails" scenarios (a held cart, the store left, then a late answer, a sign-out or a same-user re-sign-in: no error reported, and an uncaught error would fail the test) and mutant W01. **Bricks copy this pattern, so they copy the guard with it.** Every other bloc in the package was checked: none adds after an await (the category page's paging writes go through `PagingController`, which ignores answers after its disposal, and its name lookup checks `isClosed`).
- **Check after every await, before every write** (F-0040 fact 21): `fetch()` reads the epoch, sends the request pinned to it (`authPinned`, T-0050), and answers null when the epoch moved, so the base writes nothing. A user switch right before the read leaves (`signs in just before the app sends`) ends on the new user's cart with no error reported.
- The first handoff also invalidated in-flight loads on sign-out and checked `state is _Ready` before opening the cart; both were dead guards behind the epoch check and the UI (no test could kill them) and were removed (F-0051: a dead guard is worse than none).

## 3. The flag pattern (first use of `mc_feature_flags`)
- **Declare the flag as a `const` in the feature** (`flags/store_home_flags.dart`): `FeatureFlag<bool>(key: 'store.home_featured', defaultValue: true, codec: BoolFlagCodec())`. The kit holds none.
- **The page decides which sections exist, once per visit**: `late final bool _featured = context.di<FeatureFlagsReader>().value(storeHomeFeatured)` in the page's state. A section that is off has no `BlocProvider`, so its bloc never exists and its endpoint is never called. Reading once means a remote fetch that lands later does not make a section appear or vanish under the reader. Pinned (Verifier round) by `flow_scope_test` "the flag is read once per visit": the flag turns on and the page rebuilds, and featured stays absent with 0 requests; the next visit shows it. Mutant W07 (a getter instead of `late final`) is killed by it. Pull to refresh with the flag off reads no featured bloc either (W06).
- `FeatureFlagsReader` is a root import of the flow (it is pure Dart).
- **Tests (P-107 resolved):** `McTestContainer` registers `McTestFlags`, a stub remote snapshot, as the root's `FeatureFlagsReader` (no `/v1/flags` request reaches the strict harness). The generic step `the flag {key} is {value}` sets a raw value (a literal, or a string read as JSON when it parses); the flag's own codec decodes it, so a wrong type is the default, as in the app. Scenarios: off (absent, 0 requests), on (the control), wrong type (default). `mc_test_steps:flag_steps_test` has the negative controls.

## 4. The analytics pattern (first use of `mc_analytics`)
- **Blocs track through a pure-Dart port.** `mc_analytics` is a Flutter package (its observers), so a bloc may not import it (R15). `AnalyticsTracker` (`trackEvent`, `trackScreen`) is in `mc_monitoring`, which every bloc already depends on; `Analytics` implements it and `AnalyticsDIInitializer` registers it, so the consent gate, validation and sessions still apply. A flow lists `RootImport<AnalyticsTracker>()`.
- **The feature spells its vocabulary once**: `domain/model/store_analytics.dart` holds the event names, the `section` and `kind` enums and an extension on the port (`sectionViewed`, `itemTapped`). Blocs call intents, never raw names.
- `store_section_viewed` (`section`): once per bloc, so once per visit, the first time the section is `ready`: not when it failed or is empty, and after a Retry that succeeds. `store_item_tapped` (`section`, `kind`, `id`): `kind` is what the tap leads to (`comic`, `category`, `search`, `cart`), `id` the target's id.
- **Pages inside a flow (P-103 resolved).** `FeatureFlow(observers: [...])` (new, read once) attaches observers to the flow's own navigator, and `mc_analytics`' `AnalyticsFlowObserver` tracks its pages by their `McFlowPage` names. Rules the bricks follow:
  - name a flow's pages with their screen names, and **the first page as its route** (`store_home` for the route `store_home`): the route observer tracks the route, and the flow observer does not repeat its first page under the same name;
  - a page pushed or popped inside the flow is tracked while the flow's route is current; one changed while another screen covers it is tracked when the route comes back;
  - coming back to the route (Back from a comic) tracks **the page the flow shows**, not the route's name: the route observer reads the flow observer's per-route record.
    - **the order the first-page rule relies on:** the route observer reports the route first, because `FeatureFlow` builds its navigator (and so its first page) only once its container's future resolves, a frame later. A flow that built its first page synchronously would track it twice; `mc_feature_flow:feature_flow_test` "a flow builds its first page a frame after it is built itself" fails in that case (Verifier round, ADR-0012);
  - **in a nested flow** the flow observer's host is the outer flow's page, and `outerIsCurrent` composes with the outer scope's. No flow is nested today; `feature_flow_test` "a nested flow is visible only while the flow around it is" pins the visibility (mutant W02).
  So store → category → back is `store_home, store_category, store_home` in the app, and category → comic → back is `…, comics_details, store_category`. In a feature test (no route observer) the first page is tracked too. `mc_analytics:flow_observer_test` and `mini_client:analytics_screens_test` pin both.
- **Review round.**
  - **The host is looked up without a dependency:** `AnalyticsFlowObserver(tracker, host: (c) => FlowScope.read(c).outerRoute)`. `ModalRoute.of` from the flow navigator's context made that navigator depend on the host route's status. The test checks that the flow navigator lists no `_ModalScopeStatus` dependency (it fails with `ModalRoute.of`), and that covering the host rebuilds no flow page.
  - **A page changed under a popup** (a dialog over the host) is tracked when the popup closes: the route observer, seeing the same route on top again, reports the flow's page if it differs from what it last reported for that route.
  - **`FlowScope.updateShouldNotify` compares values, not the host route's identity (Verifier round).** `outerRoute` is the same route for the scope's whole life (the flow's state lives in it), so its identity check was a dead term; `outerIsCurrent` is now compared directly (mutant V08).
  - **Unnamed and invalid flow page names** are recorded (as `''` or the name) but not tracked, so coming back to the route never reports the page *before* them. Flow page names pass `AnalyticsRules.isValidName` and are exempt from the router's declared-name filter: that filter exists because go_router names an unnamed page by its path, and a flow page has no path (`McFlowPage.name` is its declaration).

## 5. Money
- **Integer cents end to end.** DTO fields are `int ...Cents`; the domain holds `Money(minorUnits, Currency)`; `Currency.parse('EUR')` (new in `mc_formatters`) refuses an unknown or lower-case code with a `FormatException` (so a bad body is `ApiMalformed`). The feature formats with `formatMoney(money, locale)`: `€12.99` in en, `12,99 €` (no-break space) in de; `mc_formatters` tests every cent below €100 digit for digit.
- `architecture_test` fails on any `double`, `num`, `toDouble`, `round`, `floor`, `ceil` or `truncate` in the generator-read files (domain, blocs, flags), with controls.
- Test oracles never use the app's formatter: the env's `euros(cents)` and `eurosDe(cents)` build the expected text from the cents, and the cart's expected count and total come from the backend engine, read with a minted token.
- **"Ends in N days" against an injected clock.** The flow takes `clock`, provides it as `StoreClock` (flow-provided, not a root import), and the deals bloc reads it when the deals arrive. **Ended deals are left out (review round):** a deal runs until `endsAt` exactly (`Deal.runsAt`), so one at or after its end is not shown, and a list of only ended deals is the empty state. `daysLeftAt` counts whole days, rounded down: 25 h is "Ends in 1 day", 23 h and 1 h are "Ends today". Boundaries are pinned in `contract_test` and `flow_scope_test`. The wiring passes the mocked backend's fixed clock (`commerceClock`), so the app's deals end 1 to 8 days after `2026-01-01`.

## 6. Navigation shape
- Four navigator methods: `openComic`, `openSearch`, `openCart` (a placeholder route `/store/cart` for now) and `requestSignIn`. Deferred: `openCheckout()` and `openPromo(code)`.
- A category is a page of the flow, not a route. `/store/categories/:id` (a child of `/store`) builds the flow **with the category as its only page**, so after a cold link Back walks category → store → home instead of passing through a second store home inside the flow.
- A banner or a deep link does not know the category's name; the category bloc looks it up once (`GET v1/store/categories`) and writes it into the flow state, which titles the page.

## 7. Facts and traps
1. **`the backend holds {route}` holds every matching request**, so a refresh racing a held load was held too. `McBackendHarness.holdNext(route)` and the step `the backend holds the next {route}` hold only the next request.
2. **Scenarios, not sets, for section failures.** A domain's fixture sets register routes, so switching on `commerce.empty` after `commerce.default` throws a duplicate-route error. The new step `the backend runs the scenario {name}` switches the served domain's scenario (`store.deals_error`, `commerce.empty`); run it before any `the backend fails` step (switching resets the engine's rules).
3. **The GET retry interceptor triples a failing request** (2 retries, F-0040 fact 9): a section that fails with `server_error` costs 3 requests, and the counts in the scenarios include them.
4. **Mocktail's `verify(...).called(n)` forgets what it verified**, so a second check of a cumulative count reads only the new calls. The store env records every navigator call in order (`navigatorCalls()`), and the steps count from that.
5. **Stepping through a paged grid loads the next page.** A step that scrolls to the end to collect every card triggers `loadMore` and leaves a pending request. Read the loaded items from the grid's own `McPagedGrid.state` (dynamically: the item type is package-private) and look only at the top.
6. **Pull to refresh with a hold active:** `mcSettle` pumps two frames, which is not enough for the refresh control to fire; the store's `I pull the store to refresh` jumps to the top, drags, then pumps 100 ms frames.
7. **An `OverflowBox` in a lazy list has unbounded height**; give a carousel skeleton a fixed-height box first.
8. **`debugResolveAll` builds every registered bloc**, including the category page's, which needs an open category in the flow state: resolve from the category page.
9. `plainSpaces` must spell its characters as `  `: a literal no-break space in a source file can be normalised by the editor.

## Kit changes (T-0056)
| Package | Change |
|---|---|
| `mc_monitoring` | `AnalyticsTracker` port |
| `mc_analytics` | `Analytics implements AnalyticsTracker`, registered by `AnalyticsDIInitializer`; `AnalyticsFlowObserver`; the route observer reads a flow's page |
| `mc_feature_flow` | `FeatureFlow(observers:)` |
| `mc_test_utils` | `McTestFlags` in `McTestContainer` (P-107); `McBackendHarness.holdNext` |
| `mc_test_steps` | `the flag {key} is {value}`, `the backend holds the next {route}`, `the backend runs the scenario {name}` |
| `mc_formatters` | `Currency.parse`; en and de money tests |

## Follow-ups (for `pending-work.md`)
- `app/sandbox/commerce_sandbox` (P1-21 lists it; out of this task's scope), as P-091 did for the library sandbox.
- `openCheckout`, `openPromo` and the cart screen with the checkout feature (F078).
- `mcgen wire` for `flow_scope.dart` (as every exemplar).
