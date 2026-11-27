# T-0053: `mc_analytics` (U06), the tracking facade with a consent gate

| Field | Value |
|---|---|
| Status | In Progress |
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
