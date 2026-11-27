# T-0053: `mc_analytics` (U06), the tracking facade with a consent gate

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-27 `113e895`; Verifier PASS `458403f`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (service kit; ADR-0011) |
| Branch | `fleet/T-0053-analytics` |
| Created | 2026-11-27 |
| Depends on | `mc_prelude`, `mc_di`, `mc_config`, `mc_monitoring`, `mc_storage` |
| Related | plan 01 U06, P1-05 AC4 ("Given analytics consent off, then nothing reaches the sink"), §3.4 root DI list, §4.x pages carry a name (for analytics); LD+, SR+, FW+, DB+, IX+ sets; F060 `settings_privacy` (later); P-004 (no third-party SDK without PO sign-off) |

## Goal
Most bricks, and the DB, SR, FW and IX exemplars, track screens and events. They need one typed facade with no third-party SDK. Nothing may leave the device without consent, and the facade must be easy to assert on in BDD tests.

## Scope
- **In: `utility/mc_analytics` (UF, Flutter).** Plan deps are `mc_prelude`, `mc_di`, `mc_config` and `mc_monitoring`. Add `mc_storage` so consent persists, and justify it in the README.
  - **Events.**
    - `AnalyticsEvent` has a `name` and typed `params` (`String`, `int`, `double`, `bool` only).
    - Validation is documented: snake_case names of 1–40 characters, at most 25 params, string values at most 100 characters.
    - An invalid event is a debug `AssertionError` (so tests fail). In release it is dropped and reported once to `mc_monitoring`.
    - Reserved prefixes such as `mc_` are for the kit.
  - **Facade.**
    - `Analytics.track(event)`
    - `Analytics.screen(name, {params})`
    - `setUserProperty(key, value)` (same validation)
    - `reset()` (on sign-out; the caller decides)
  - **Consent gate.**
    - The states are `unknown`, `granted` and `denied`, persisted in `mc_storage`. The default is `unknown`.
    - With `unknown`, events are buffered in memory, capped at 100 with the oldest dropped and the drop count reported.
    - `granted` flushes the buffer in order. `denied` discards it.
    - Nothing reaches any sink unless consent is `granted`. That is P1-05 AC4.
    - Changing to `denied` discards the buffer and stops delivery at once, including an event tracked in the same turn.
    - `Stream<AnalyticsConsent>` is exposed for the future settings screen.
  - **Sinks.** `AnalyticsSink` is an interface. It comes with:
    - `InMemoryAnalyticsSink`, for tests and the BDD steps;
    - `MonitoringAnalyticsSink`, which forwards to `mc_monitoring` as `EventEntry` so dev builds can see events in the log;
    - no network sink, because P-004 needs PO sign-off first.

    A sink that throws must not break the app or the other sinks. The kit reports it once.
  - **App sessions.**
    - A session id is generated from an injectable random source.
    - It rotates after 30 minutes in the background, using `AppLifecycleState` with an injectable clock. A cold start always starts a new session.
    - Every delivered event carries `session_id` and a per-session `seq` that starts at 1 and has no gaps among delivered events.
    - The kit emits `mc_session_start` when a session begins.
  - **Screen tracking.**
    - `AnalyticsRouteObserver` is a `NavigatorObserver` that calls `screen()` with the route's `settings.name` whenever a page route becomes current through push, pop or replace.
    - Unnamed routes and popup or dialog routes are ignored, and there are no duplicates when the same route becomes current again without a change.
    - Add the observer to the app's `GoRouter` (`app_core`). Name any home or flow pages that have no `name` yet, using the plan's page naming, so every screen tracks once.
  - **DI.**
    - Add `AnalyticsDIInitializer` to `rootInitializers` after `MonitoringDIInitializer`, as plan §3.4 orders it.
    - Update the comment there.
    - In the `e2e` and `dev` configs, consent is `granted` by default through `AppConfig`, so developers see events. In release-like builds it starts at `unknown`.
  - **`mc_test_steps`.** Add generic BDD steps:
    - `the analytics event {name} was tracked` (with optional params);
    - `no analytics event was tracked`;
    - `the screen {name} was tracked`.
- **Out:** exposure events for flags. The app_core wiring of `mc_feature_flags` to analytics is a follow-up once both exist, so record it in the handoff and don't build it. Also out: a network or vendor sink, the privacy settings screen (F060), and Android.

## Acceptance criteria
- **T-0053-AC1 (consent):** P1-05 AC4.
  - With consent `unknown` or `denied`, 0 entries reach any sink, across track, screen and user properties.
  - `unknown → granted` flushes the buffered events in order, with the correct session and sequence numbers.
  - `unknown → denied` discards them.
  - Both buffer-cap boundaries (100 and 101) are pinned.
  - An event tracked in the same turn as a switch to `denied` is not delivered.
  - Consent persists across restarts.
  - Mutations that remove the gate or reorder the flush must be killed.
- **T-0053-AC2 (validation):** each rule and boundary has a test. Debug builds throw; release-mode handling drops the event and reports it to monitoring exactly once. Test the release path with an injected mode flag, not by building in release.
- **T-0053-AC3 (sessions and sinks):**
  - The session rotates at 30 min in the background, with 29:59 and 30:00 pinned.
  - A cold start gives a new session, and `seq` has no gaps.
  - A sink that throws doesn't stop the other sinks and is reported.
  - `MonitoringAnalyticsSink` forwards the events.
- **T-0053-AC4 (screens):**
  - A widget test with a real `GoRouter` records the screens for push, pop, `go` and a dialog (ignored).
  - In the app, home → characters → back records `home`, `characters_list`, `home`. Use the real page names. Add an app-level test, and run the e2e on your own simulator.
  - The new BDD steps are used in at least one feature scenario, for example the characters list screen tracked. Prove each step with a negative control.
- **T-0053-AC5 (gates):**
  - Coverage ≥ 90 %.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and `l10n_check` pass.
  - Globs use `MC_GENERATED_DART`.
  - The sim app builds and the mini_client e2e passes on your own simulator. Delete the simulator afterwards.
  - Provide `tool/checks/T-0053-AC5_gates.sh` and a mutation script that refuses a dirty tree and tells a broken build from a killed mutation.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer (Sonnet). `utility/mc_analytics` built and registered (root `pubspec.yaml`; `pubspec.lock` and `MODULE.bazel.lock` unchanged: no new third-party package, and `go_router` is only a test dependency). Branch `fleet/T-0053-analytics` from `6aba350`.
- 2026-11-27: Decisions inside the scope (details in the package README and F-0053):
  - **Delivery is a microtask after `track`**, with consent re-read for every entry, so an event tracked in the same turn as a switch to `denied` (before or after it) is never delivered. `setConsent` changes the state synchronously; only the saving is asynchronous.
  - **Session fixed at track time, `seq` at delivery**, so buffer drops leave no gap and buffered entries across a rotation keep their own session.
  - The kit's own `mc_session_start` takes one of the 100 buffer places. Overflow is reported at the first drop and again with the total when consent is chosen.
  - `screen()` is the kit event `mc_screen_view` with `screen_name`; a user property is its own record type. Reserved prefixes: `mc_`, `ga_`, `firebase_`, `google_`; reserved param keys: `session_id`, `seq`, `screen_name`. A string's 100 characters are Unicode code points.
  - The observer uses `NavigatorObserver.didChangeTop` (one hook for push, pop, replace and `go`), tracks only page routes whose name is a valid screen name, and has a `lazy` constructor (the router is built in unit tests with no container).
  - Config: `AppConfig.analytics.defaultConsent` (optional); `dev.json` and `e2e.json` say `granted`, `perf.json` says nothing (`unknown`). A saved choice wins; a damaged one gives `unknown`.
  - `AnalyticsDIInitializer` sits right after `StorageDIInitializer` in `rootInitializers` (it needs the file store), not after monitoring as plan 01 lists it. The test container has the same order.
  - Steps: `the analytics event {name} was tracked`, `... was tracked with` (a `key | json` table, as the body step), `no analytics event was tracked` (kit events and screen views excluded), `the screen {name} was tracked`.
  - Page names: every typed route now has a `name` (see "Changes outside the package").
- 2026-11-27: Changes outside `utility/mc_analytics` (each needed by the scope):
  - `utility/mc_config`: `AnalyticsConfig` and `AppConfig.analytics` (the scope's "through `AppConfig`"); tests added. `tool/bazel/config/dev.json` and `e2e.json`: `analytics.defaultConsent: granted`.
  - `app/wiring/app_core`: `rootInitializers` (+ `AnalyticsDIInitializer`, `analyticsSinks:`), `appRouterObservers()`, deps. Two existing tests edited, neither weakened: `formatters_root_test` calls `TestWidgetsFlutterBinding.ensureInitialized()` (the root list now observes the lifecycle) and `mc_test_utils`' `isolation_test` expects 10 root initializers, not 9.
  - `app/mini_client`: `buildAppRouter` gets `observers: appRouterObservers()`; `HomeRoute` and `PlaceholderRoute` get names; BUILD and pubspec (`mc_analytics`, `mc_test_steps` for tests); a new test, a BDD feature (`test/feature/`), an e2e journey.
  - Page names (all typed routes; before, go_router used the path): `home` (`/`), `placeholder_detail`, `characters_list`, `character_details`, `comics_details`, `creator_details`, `discovery_search`, `reading_list_new`, `reading_list_edit`. The edits are in `universe_wiring`, `publishing_wiring`, `discovery_wiring`, `library_wiring` and `app_routes.dart`. Names are unique (a test walks the tree).
  - `utility/mc_test_utils`: `McTestSession.analytics` (an `InMemoryAnalyticsSink`), `AnalyticsDIInitializer` in `McTestContainer` over it (consent granted, no lifecycle observer). `utility/mc_test_steps`: the four steps in `lib/src/analytics/`, a test with negative controls.
  - Workspace `pubspec.yaml`: `utility/mc_analytics`.
- 2026-11-27: Not done, by scope: exposure events for feature flags (a follow-up once both packages exist), a network or vendor sink (P-004), the privacy screen (F060), Android. Not tracked yet: the pages inside a flow (`McFlowPage`), and the universe sandbox router has no observer. See F-0053.
- 2026-11-27: Review-minded fixes found by the mutations (all pinned by tests now): a sink that moves consent to `unknown` in the middle of a flush; the reserved lists were only checked through themselves; a failing `ConsentStore.save`; `granted` then `denied` in one turn; the order of two saves in one turn.

## Outcome
`utility/mc_analytics` (archetype UF, Flutter) is registered in the workspace: the `Analytics` facade (`track`, `screen`, `setUserProperty`, `reset`, `setConsent`, `consentChanges`), the consent gate with a persisted choice, app sessions from an injected clock and random, `InMemoryAnalyticsSink` and `MonitoringAnalyticsSink`, `AnalyticsRouteObserver`, `AnalyticsLifecycleObserver` and `AnalyticsDIInitializer`. It is in `rootInitializers` and `McTestContainer`, the router carries the observer, every typed route has a page name, and `mc_test_steps` has the four analytics steps. No third-party SDK and no network sink. Package README: `utility/mc_analytics/README.md`. Design record and gotchas: [F-0053](../findings/F-0053-analytics.md).

| AC | Evidence |
|---|---|
| AC1 (consent) | `consent_gate_test.dart` (`T-0053-AC1`): unknown and denied deliver 0 across track, screen and user property (also through `MonitoringAnalyticsSink`); `unknown -> granted` flushes in order with session and seq (also across a rotation); `-> denied` discards, and a later grant does not bring it back; same-turn `denied` both before and after the switch, `granted` then `denied` in one turn, a sink that denies or goes back to `unknown` in the middle of a flush; buffer of 100 (99 user entries plus the session start fit) and 101 (the oldest drops, `seq` has no gap, the drop count is reported, then again as a total); consent persists (`ConsentStore` over a real directory, saved beats default, a damaged value never grants, two saves in one turn keep the last); `consentChanges`. `di_test.dart` (config default, saved denial beats a granted default across a restart). `mc_config` `app_config_test` and `bundled_config_test` (dev and e2e `granted`, perf `unknown`; per-env run in the gates script). App level: `analytics_screens_test.dart` (a release-like config buffers 3 entries and delivers 0; granting flushes them in order). Mutations G01 to G28 |
| AC2 (validation) | `validation_test.dart` (`T-0053-AC2`): name 1 / 40 / 41 and the empty name, snake_case cases, each reserved prefix and param key (spelled out), 25 / 26 params, key 40 / 41, string 100 / 101 (emoji count as characters), NaN and infinity, unsupported types, every broken rule listed; debug throws `AssertionError` for track, screen and user property, also while denied; release (`debugMode: false`) drops and reports exactly one `AnalyticsValidationError` per entry however many rules it breaks, with no `seq` gap. Mutations V01 to V19 |
| AC3 (sessions and sinks) | `sessions_sinks_test.dart` (`T-0053-AC3`): 29:59 keeps and 30:00 rotates (injected clock), hidden / paused / detached background and inactive does not, a second backgrounding keeps the first time, a backwards clock does not rotate, every cold start is a new session from the injected random (32 hex), `seq` from 1 with no gaps and restarting per session, `mc_session_start` with its reason, `reset`; a throwing sink does not stop the others and is reported once per sink; `MonitoringAnalyticsSink` forwards events and user properties as `EventEntry`. `di_test.dart` (the real `WidgetsBinding` lifecycle rotates the session; disposing stops observing). `no_third_party_test.dart` (imports whitelist, with a control) and the closure check in the gates script (positive and negative controls). Mutations S01 to S24 |
| AC4 (screens) | `route_observer_test.dart` (`T-0053-AC4`): a real `GoRouter` records push, pop (`home, characters_list, home`), `go`, replace and a nested route; a dialog and a bottom sheet are ignored and a dialog closed over a page does not repeat it; an unnamed page is not tracked but coming back to the page below is; the same screen pushed twice is tracked twice; a plain `Navigator` (push, replace, remove) and bad names. App level: `app/mini_client/test/analytics_screens_test.dart` (the real app records `home, characters_list, home` for home, Characters, Back; a cold link tracks `character_details` once; every route is named, valid and unique). BDD: `app/mini_client/test/feature/app_screens.feature` (3 scenarios, `@T-0053-AC4`) uses `the screen {} was tracked` and `no analytics event was tracked`; `mc_test_steps` `analytics_steps_test.dart` proves all four steps with negative controls (wrong name, missing, extra and mistyped param, a feature event, denied consent). E2E on my own simulator: `integration_test/analytics_screens_test.dart` PASS, the whole mini_client e2e 11/11 PASS (`documents/evidence/T-0053/engineer/mini_client/e2e-summary.md`, screenshots `01_home`, `02_characters_list`, `03_back_to_home`); negative control with the router observer removed FAILS (`e2e_negative_control/`, script `e2e_negative_control.sh`). Mutations R01 to R05, W01 to W12 |
| AC5 (gates) | `tool/checks/T-0053-AC5_gates.sh`, report `documents/evidence/T-0053/engineer/AC5_gates.md`: no network client or SDK in the closure (positive and negative controls), globs use `MC_GENERATED_DART` (with a negative control), registration, touched packages 39/39 uncached, then `test //...` all green, `test --lockfile_mode=error //...`, bundled config for dev, e2e and perf, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, coverage: `mc_analytics` 275/275 = 100 %, `mc_config` 100 %, `app_core` 95.7 %, `mini_client` 95.5 % |

Mutations: `documents/evidence/T-0053/engineer/mutations.sh` (`MC_TASK=T-0053 MC_ROLE=engineer`; specs in `mutation_specs.py`; refuses any dirty tree, sets its restore trap before the first edit, counts `Build did NOT complete` and timeouts as **broken** and only `FAILED in` as **killed**, builds mutants without the analyzer so dead code left by a mutation cannot hide a surviving test), log `mutations.log`: **88/88 killed**, none survived, none broken. The first run found 4 survivors (`consent` re-read per entry only pinned for `denied`, a reserved-prefix list checked through itself, a failing `ConsentStore.save`, the e2e config); each got a test and now dies. e2e negative control as above.

Test integrity: no test deleted, skipped or weakened; no `// ignore:`; no golden touched. Two existing tests were edited, see the Log. Globs use `MC_GENERATED_DART`. The simulator `mc-T-0053-engineer-*` was deleted after every e2e run, and Bazel was shut down.

## Review round
`/code-review` found 2 important bugs and 6 nits; all are fixed. `origin/main` was merged first (T-0049, T-0050 and the rest): no conflict, the lockfiles did not change, the route names survive `nestUnderHome` (a test walks the nested tree), and the `isolation_test` count stays 10.

| # | Finding | Fix | Test (and mutation) |
|---|---|---|---|
| 1 | The BDD screen scenarios were vacuous (`contains`) | New exact, ordered step `the screens tracked are {'home, characters_list, home'}`; the three scenarios use it | `analytics_steps_test` (missing, extra, repeated, reordered, renamed, empty); `app_screens.feature`. X11 (no re-track on pop) and X12 (home twice on start) are killed by `bdd_test`; X13, X14 by the step test |
| 2 | `reset()` dropped this turn's events | `reset()` keeps entries already queued (granted), delivered under their own session and `seq`; only the buffer waiting for a choice (`unknown`) is dropped; documented in the code and README | `consent_gate_test`: granted, unknown, denied. G18 and G18B (clear again) killed |
| 3 | Unnamed nested routes tracked under their path | The observer takes the router's declared names (`screenNames`, `goRouteNames` from `GoRoute.name`); the app passes them lazily. The route-tree naming test stays | `route_observer_test` (unnamed `settings` not tracked, `profile_page` is; control without the set tracks `settings`), `router_observers_test`. X06 killed |
| 4 | `dispose()` | `track`, `screen`, `setUserProperty`, `setConsent`, `reset` and the lifecycle calls are no-ops; nothing is saved | `consent_gate_test` group "a disposed Analytics". X01, X02 killed. The guard in the drain was redundant (dispose clears the queue), so it was removed |
| 5 | The observer must never break navigation | `appRouterObservers` returns null when `Analytics` is not registered; the observer then tracks nothing | `router_observers_test` and `route_observer_test` navigate with no container. X07, X08 killed |
| 6 | `screen()` param cap | 24 own params are accepted, 25 are rejected (`screen_name` counts) | `validation_test` boundary (debug and release). X04, X05 killed |
| 7 | Wrong-typed `defaultConsent` | A non-string value, or a section that is not an object, is `unknown` | `app_config_test`. X09 killed |
| 8 | DI ordering | Register `Analytics` first, then add the lifecycle observer; the observer is also registered so a test can prove disposing removed it | `di_test` (double registration leaves no observer; `removeObserver` is false after reset). X10 and S22 killed |

Decisions: the ordered step splits its text on commas and ignores spaces, and `{''}` means no screens. `screenNames` is a lazy callback because the router does not exist when its observers are made. Mutants of the review run: **102/102 killed** (88 earlier ones plus G18B and X01 to X14, minus the dropped X03), `mutations.log`.

New Definition of Done rule: the targets this task adds or changes that touch storage, lifecycle or races pass `test --runs_per_test=50 --nocache_test_results` with 0 failures (14 targets, `runs_per_test_50.log`). Two widget tests dropped a consent save (`unawaited(setConsent(...))` under fake async): they now `await tester.runAsync(...)`, so the write finishes before the directory is deleted.


## Merge (TL)
- 2026-11-27: Review-first (ADR-0011). `/code-review` found 2 important bugs:
  - the BDD screen steps used `contains`, so the go-back scenario passed vacuously;
  - `reset()` dropped events tracked earlier in the same turn.

  It also found 6 nits. All were fixed in the review round at `5d1a596` (102/102 mutations killed, 50-run flake check clean, e2e 11/11). A single Sonnet Verifier pass gave PASS `458403f` (about 125k tokens; own 13-test probe; 19/19 mutations killed; 50-run flake check on 13 targets; e2e 11/11; no defects). The TL merged `--no-ff`. On the merge result `check` passed, 165/165 tests passed, lint was clean, `mc_arch_check` reported OK, the sim app built and provenance passed. Follow-ups: P-102 to P-105.
