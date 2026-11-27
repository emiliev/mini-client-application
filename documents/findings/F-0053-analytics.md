# F-0053: `mc_analytics`: a consent gate that delivers a microtask later, and what the screens observer needs

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0053)
- **Type:** Design record / gotchas
- **Related:** T-0053, plan 01 U06 and P1-05 AC4, P-004, F-0038, F-0049, F-0051

## Summary
`utility/mc_analytics` is the one typed facade the bricks track through. Nothing leaves the device (P-004), and the consent gate is the part reviewers attack, so the design choices that matter are recorded here.

## Design facts
1. **Delivery is one microtask after `track`, and consent is read again for every entry.** The task says an event tracked "in the same turn" as a switch to `denied` must not be delivered. With inline delivery, `track(e); setConsent(denied)` would deliver `e` before the switch. So `track`, `screen` and `setUserProperty` only queue; a microtask drains the queue, checking `consent == granted` before each entry. `setConsent` changes the state synchronously (flush or discard happen at once); only saving the choice is asynchronous. A sink that denies in the middle of a flush stops the rest (tested). Tests await a microtask (`await Future<void>.value()`), never a timer.
2. **The session is fixed when an entry is tracked, the `seq` when it is delivered.** Buffered entries that span a rotation are delivered under both session ids, each counted from 1. An entry that the buffer drops (the 101st) leaves no gap in `seq`, which a seq taken at track time could not promise.
3. **The buffer includes the kit's own `mc_session_start`.** It takes the first of the 100 places. With `unknown`, 99 user entries fit and the 100th drops the session start. The drop is reported to monitoring at the first drop and again, with the total, when consent is chosen (so a build that stays `unknown` still reports).
4. **A damaged saved consent gives `unknown`, never the config default.** Otherwise a corrupt file would turn a saved `denied` into the `granted` that `dev` and `e2e` configs default to. A saved choice, once present, always wins over the config.
5. **`AppConfig.analytics.defaultConsent`** (new, optional; `granted` in `dev.json` and `e2e.json`, absent in `perf.json`) is the only way a build starts granted. This is a change in `mc_config` outside the package; every existing `AppConfig(...)` call keeps compiling (the field has a default).
6. **Validation runs whatever the consent is.** An invalid event in a build that has not been asked yet still trips the debug `AssertionError`, so the bug shows before anyone consents. In release it is one `recordError` per rejected entry (not per broken rule).
7. **Reserved prefixes are `mc_` plus `ga_`, `firebase_`, `google_`**, and `session_id`, `seq`, `screen_name` are reserved param keys, because the sinks add them. Screen names may start with `mc_`.

## Gotchas
- **`NavigatorObserver.didChangeTop` is the hook.** Flutter 3.47 calls it once whenever the topmost route changes, after pages are updated: a push, a pop, a `pushReplacement` and a go_router `go` (which rebuilds the stack from pages) all come through it, so the observer needs none of `didPush`, `didPop`, `didReplace` or `didRemove`. A dialog opening and closing over a page fires it twice (page to dialog, dialog to page); the observer remembers the last **page route** by identity and skips the repeat.
- **An unnamed page on top must still count as a change.** `A (named) -> B (unnamed) -> pop` reports `A` again, because `B` was a screen the user saw. The observer therefore sets "last" before it checks the name.
- **go_router names a page by its path when the route has no `name`.** `/search` is the page name, which is not a valid screen name, and `/` is the boot route's name. So the observer skips names that are not valid screen names rather than asserting, and the typed routes now carry `name:` (`home`, `characters_list`, `comics_details`, `discovery_search`, ...). `analytics_screens_test` walks the real route tree and fails when a route has no valid, unique name, so a new route cannot ship unnamed.
- **A flow's inner pages are not tracked.** `McFlowPage` names (`list`, `preview`) live in the flow's own `Navigator`, which has no observer. `characters_list` tracks once, as the route. Tracking inner pages would need `mc_feature_flow` to install an observer; that is a follow-up.
- **The observer looks `Analytics` up lazily** (`AnalyticsRouteObserver.lazy`). `buildAppRouter` is called by plain unit tests with no container; resolving at construction would have broken `T-0049-AC3` and `AppLocations match the typed routes` without any change to them.
- **`await analytics.setConsent(...)` hangs inside `testWidgets`.** Saving is real file I/O (F-0038). In a widget test call `unawaited(setConsent(...))`: the choice applies at once anyway. Plain `test()` bodies can await it.
- **A plain `test()` over `rootInitializers` now needs a binding** (`TestWidgetsFlutterBinding.ensureInitialized()`), because the analytics initializer observes the app lifecycle. `app_core`'s `formatters_root_test` got that line. Pass `observeLifecycle: false` where there is no binding.
- **`expectLater(step, throwsA(isA<TestFailure>()))` in `mcTestWidgets` ended the test early** (a guarded `pump` was still running when `_finish` pumped). A negative control for a step is a `try { await step } on TestFailure { return; } fail(...)` helper. Also, `expect(iterableOfMaps, contains(map))` did not match an equal map from `Map.unmodifiable`; the step uses `mapEquals` over `any`.
- **`mc_bdd_tests` adds `flutter`, `flutter_test` and `mc_test_utils` itself**; listing them again in `deps` is a Bazel "duplicated label" error.
- **Mutants must be formatted** (F-0051 fact 2): the Bazel build checks `lib/` formatting, so `mutations.sh` formats each mutated file before the tests, or every mutant is "broken".

## Test-container and root-list order
Plan 01 lists analytics right after monitoring. It needs the file store for the consent choice, so it comes right after storage in `rootInitializers` and in `McTestContainer` (same list, same order). The container's `AppConfig` has `defaultConsent: granted` and the session owns the `InMemoryAnalyticsSink` the BDD steps read, so every feature test can assert on analytics without setup.

## Follow-ups (not done here)
- Exposure events for feature flags: wire `mc_feature_flags` to `Analytics` once both exist (T-0052).
- Track the pages inside a flow (an observer in `FeatureFlow`), if the PO wants them as screens.
- The universe sandbox router has no analytics observer yet.
- Call `Analytics.reset()` from sign-out when the account feature exists; the privacy settings screen (F060) calls `setConsent`.
- A network or vendor sink needs the PO's sign-off first (P-004).
