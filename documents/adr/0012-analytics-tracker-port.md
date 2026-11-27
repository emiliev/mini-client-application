# ADR-0012: Blocs track analytics through a pure-Dart port; a flow's pages are screens

- **Status:** Proposed
- **Date:** 2026-11-27
- **Deciders:** Tech Lead (accepts at the T-0056 merge)
- **Related:** T-0056, T-0053, P-103, F-0053, F-0056 §4, R15, R17, ADR-0007

## Context
`store_home` (T-0056) is the first feature to track analytics, and every brick of P1-24 copies it, so the way a feature tracks is costly to change later.

- **R15: blocs import no Flutter.** Code generators (freezed, injectable) read the blocs on analyzer summaries, and a Flutter library in that closure crashes the shim (F-0007). `mc_analytics` is a Flutter package because its `AnalyticsRouteObserver` and `AnalyticsLifecycleObserver` need Flutter (T-0053). So a bloc cannot take `Analytics`.
- **Events belong in blocs.** "Viewed once a section is ready" and "an item was tapped" are decisions a bloc makes, next to the navigator calls (plan 01 §4.1).
- **Screens inside a flow were not tracked (P-103).** The app's router observer sees only routes. A flow's pages live in the flow's own navigator, so the category page inside the store, the characters preview and the wizard steps were invisible.

## Options considered
### A. A pure-Dart port in `mc_monitoring`, implemented by `Analytics` (chosen)
- Pros:
  - One general mechanism. A brick writes no adapter.
  - Neither kit gains a dependency, because every bloc already depends on `mc_monitoring` (`McBloc`).
  - The consent gate, validation and sessions still apply: the port is `Analytics` itself, registered as the same instance by `AnalyticsDIInitializer`.
- Cons:
  - An analytics type lives in the monitoring package.
  - The port is small (`trackEvent`, `trackScreen`); richer APIs (user properties) are not on it.

### B. A port and adapter per feature
- Pros: no kit change.
- Cons:
  - Every feature writes an interface, an adapter in a Flutter file, a `provide:` registration and a hand-listed root import. That is boilerplate the bricks would multiply about 70 times.

### C. Split `mc_analytics` into a pure core and a Flutter part
- Pros: the analytics types stay in one place.
- Cons:
  - Two library targets for one package break R8, or a new package.
  - The observers would move. T-0053's tests, `app_core` and `mc_test_utils` change, while T-0054 was changing `app_core`.

### D. Track from widgets (a `BlocListener`)
- Pros: no port.
- Cons:
  - The logic ("once per visit", "not when failed") sits in UI code, outside the blocs' tests and mutations.
  - A second DI lookup in UI code.

For screens inside a flow:
- **(a) A generic `FeatureFlow(observers:)` plus `AnalyticsFlowObserver` in `mc_analytics` (chosen).** `mc_feature_flow` stays free of analytics.
- **(b) A `trackScreens` switch in `FeatureFlow`.** This needs `mc_feature_flow` to depend on `mc_analytics`.
- **(c) The router observer finds flows itself.** It cannot see a flow's navigator.

## Decision
1. **`AnalyticsTracker`** (`mc_monitoring`) is the port: `trackEvent(name, [params])` and `trackScreen(name)`.
   - `Analytics implements AnalyticsTracker`, and `AnalyticsDIInitializer` registers it as the same instance.
   - A flow lists `RootImport<AnalyticsTracker>()`, and its blocs take the port in their constructors.
2. **A feature spells its analytics vocabulary once:** event names, parameter enums, and an extension on the port (`store_analytics.dart`). Blocs call intents, never raw names.
3. **A flow's pages are screens.** The flow passes `observers: [AnalyticsFlowObserver((c) => c.di<AnalyticsTracker>(), host: (c) => FlowScope.read(c).outerRoute)]`. The host is looked up without a dependency, so its status changes do not rebuild the flow.
   - **Rule: a flow's first page has the same name as its route** (`store_home` for the route `store_home`). The route observer tracks the route, and the flow observer does not repeat the first page.
   - A page pushed or popped inside the flow is tracked while the route is current.
   - A page changed while another screen or a popup covers the route is tracked when the route comes back.
   - Coming back to the route tracks the page the flow shows, not the route's name.
   - A flow page name passes `AnalyticsRules.isValidName`. The router's declared-name filter does not apply: it exists because go_router names an unnamed page by its path, and a flow page has no path.
4. **A visit** (for "once per visit" events) is the page's life, from the first time it is shown to its disposal. "Shown" means that it is its flow's top page and its flow's route is the app's current route (`FlowScope.outerIsCurrent`). A page built under another screen (the store below a cold category link) does no work and tracks nothing until it is shown. A screen opened and closed over it is the same visit.

## Consequences
- **Positive:**
  - Bricks track from blocs with no adapter, under the consent gate.
  - Flow pages are screens everywhere.
  - The rules are pinned by `mc_analytics:flow_observer_test`, `mini_client:analytics_screens_test` and the T-0056 mutations.
- **Negative / trade-offs:**
  - An analytics type lives in `mc_monitoring`.
  - The port is minimal; a feature that needs user properties uses `Analytics` from Flutter code.
  - A flow whose first page is named unlike its route reports both names; the rule must be followed.
- **Follow-ups:**
  - `mcgen wire` lists `AnalyticsTracker` among a flow's root imports.
  - The characters preview and the wizard steps adopt `AnalyticsFlowObserver` and screen names.
  - Exposure events for experiments (P-102) can use the same port.
