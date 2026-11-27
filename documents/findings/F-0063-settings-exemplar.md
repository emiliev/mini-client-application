# F-0063: The settings exemplar: app-wide state in a utility, a synchronous device copy, the merge rule, and what the ST bricks copy

- **Date:** 2026-11-27
- **Author:** crew: Engineer (T-0063)
- **Type:** Design record / Lesson / Kit gap
- **Related:** T-0063, ADR-0013 (proposed), ADR-0012, P1-22, plan 01 §3.3, §6.1, F056; F-0050, F-0052, F-0056, F-0058, F-0061

## Summary
`settings_appearance` is the sixth exemplar (ST): theme mode, density and Reduce motion, applied by the **whole app** at once, kept on the device, and synced with the signed-in user's account. The values are app-wide, so they live in a new pure-Dart utility, `mc_appearance`, in the root container; the feature is a screen over its port (ADR-0013). **No codegen shim failed**: the 4 freezed and injectable outputs equal build_runner's (`T-0063-AC7_matches_build_runner.md`). The ST bricks copy sections 1 to 6; section 7 lists the traps.

## 1. Where an ST feature's state lives
- **Screen-local settings** (notifications, privacy): the feature owns its retrofit API and repository, as the other archetypes do.
- **App-wide settings** (appearance, language, accessibility): a pure-Dart utility in the root list, with two ports: a reader for the app shell (`AppearanceReader`: `snapshot`, `changes`) and a writer for the screen (`AppearanceSettings`: `change`, `reset`, `retry`). The feature lists the writer as a `RootImport`, and never imports `dio`, `mc_api_client` or `mc_session` (`architecture_test` checks it).
- **The bloc holds no copy of the values.** Every state is the utility's snapshot (values, sync status, save failure), re-read on each `changes` event, so a sync or a session change anywhere shows at once. The bloc's job is intent: ignore a choice equal to the current value (no save, no request, no event), track `settings_changed`, and await `requestSignIn()`.

## 2. The device copy is synchronous
- `FileStore.readSync`/`writeSync` (new in `mc_storage`, temp file then rename) keep one small value per key. `change` returns with the value on disk.
- Why: the saved theme must be known before the first routed frame; and an asynchronous save still running at teardown deletes-while-writing (`Directory not empty`, F-0050 §7). A synchronous save cannot outlive its call, so no test has to wait for it and none can flake on it. Only for tiny values; never mix it with the async `write` for one key.
- A failed save is not a sync error: the value still applies, the screen shows the bloc's `failure` ("applies now, but this device could not save it") with Retry, which saves again. Reachable in BDD with the shared `the app can no longer write to storage`.

## 3. The merge rule and the 409 policy (copy them for any synced setting)
- **Pending** = settings changed on this device and not yet confirmed by the account, saved with the user they belong to (`pendingFor`, null when changed signed out).
- On every new session epoch the account is read; **the account wins except for pending settings**, which go on top and are sent. Another user's pending settings are dropped (A's choice never reaches B). Sign-out keeps the shown values and drops what was pending.
- The device also saves the **account version it last saw, and for whom** (`seenVersion`, `seenFor`). An account behind that version (for the same user) lost a write: the device copy is sent again. This is what makes "signed in, kill and relaunch, still Light, and the server holds Light" true against the in-process mocked backend, which is back at its seed after every kill (ADR-0005).
- One request at a time; a `PATCH` carries only the pending keys and `ifVersion`. A change made while a request is out is sent after it (the run loop re-reads pending after each answer).
- `409` with `current`: take `current`, re-apply only the pending keys, send once more on `current.version`. `identity.preferences_conflict` (an injected 409 whose `current` equals what we had) ends `synced` after exactly 2 PATCHes; a real other-device change in an untouched key ends `conflictResolved`; a second 409 ends `offline`.
- **Errors never block a local change**: any failure only moves the status to `offline`; the next change or Retry reads the account again (it may have moved), then writes.

## 4. The session-epoch rule
- Every write is pinned (`authPinned(epoch)`, T-0050) to the epoch the run started in; reads are not (their answers are dropped).
- **After every await, before any apply or save**, the run checks the epoch; an old run simply returns. A run is per epoch: a new epoch starts its own, and `settled()` waits only for the current one (an old run may wait on a held request forever).
- `change()` first handles a session change the stream has not delivered yet (`_observeEpoch()`), so a change always belongs to the session current now.
- Proved in both orders with held requests (no timers): the switch before the PATCH leaves (the pin: 0 PATCHes reach the server) and after it left (held before the server, or after it answered: the late answer changes nothing, B's values show). `mc_appearance:races_test` and the feature's two race scenarios.

## 5. The shell
- `McApp` reads `AppearanceReader` from the root once boot is ready (`McApp.rootAppearance`, overridable with `appearance:`), applies it to `themeMode`, to all four themes' `visualDensity` (`McTheme.of(variant, visualDensity:)`, new) and to `MediaQuery.disableAnimations` around the routed app, then follows `changes`. Same `MaterialApp.router`, no new router: a re-theme, not a restart. Pinned by `app_core:appearance_shell_test` and, over the real app and another feature (the characters list), `mini_client:settings_route_test`.
- Reduce motion only ever adds to the platform's setting. DS animations that read `McA11y` stop (the charts' draw-in, shown by `tester.hasRunningAnimations`).

## 6. Shape the bricks copy
- 2 pages: the settings (`settings_appearance`, the route's name) and an explainer in the flow (`settings_appearance_about`), tracked by `AnalyticsFlowObserver` (ADR-0012).
- 1 bloc, freezed state `loading` / `ready(values, sync, signingIn)` / `failure`, Tide's sealed events.
- 1 navigator method, `requestSignIn()`, for "Sync across devices" while signed out; the utility follows whoever signs in by itself.
- The confirm is UI: the page awaits `showMcConfirm` and adds `reset` only on a confirm, so Cancel cannot change anything.
- Analytics: `settings_changed` with `setting` (`theme_mode`, `density`, `reduce_motion`, `reset`) and `value` as the identity contract spells it (`dark`, `compact`, `true`, `defaults`), spelled once in `domain/settings_analytics.dart`.
- Density shows in the screen itself: gaps from `Theme.of(context).visualDensity` and a Material `SwitchListTile` (`flow_scope_test` measures both, also at 2x text, where a row is as tall as its text and only the spacing tightens).
- **No feature goldens** (PO 2026-11-27, ADR to follow). The visual ACs are widget tests: German strings on both pages (BDD), nothing overflows in the pseudo-locale at 1x and 2x (BDD), each of the 4 themes builds both pages in its palette with no error, and Compact measurably tightens the screen (`flow_scope_test`). DS kits keep their goldens.

## 7. Facts and traps
1. **`while (x case final y?)` is not Dart** (only `if`-case is). The formatter crashed on it before the analyzer said why.
2. **Records compare maps by identity**: `('e', {'a': 1}) == ('e', {'a': 1})` is false. Compare the parts.
3. **A theme change cross-fades** (`MaterialApp`'s `AnimatedTheme`): after one `pump` the visual density is still the old one. Settle before asserting.
4. **A home entry added above others pushed `Open placeholder 7` off the 800x600 test surface** in `app_test` (a lazy list builds only what is near the screen). New entries go last.
5. **A real sign-in in a feature test starts the account read on the next pump**, and a test that ends right after leaves Dio's zero-duration interceptor timers pending (`A Timer is still pending`). Hence `followAccount: false` by default in `McTestContainer`.
6. **The e2e runner uninstalls before each target** (T-0055), so a kill between two targets also wipes the data container. "Kill and relaunch" is a second `main()` in the same process after the widget tree and the root container are torn down: the files stay, the mocked backend is fresh, as after a kill.
7. **A cold link builds the flow's first page a frame after the route** (ADR-0012 §3); a test of a cold link to a flow waits for the page, not only for the route.
8. **`the backend received ... with the body` checks every matching request**; two PATCHes with different versions need the local `the preferences writes were {json list}`.
9. **The GET retry interceptor triples a failing read** (F-0040 fact 9), and a change made while offline reads the account again before it writes: `identity.preferences_error` costs 3 GETs at sign-in and 3 more per change.

## Kit changes (T-0063)
| Package | Change |
|---|---|
| `mc_appearance` (new) | The appearance, its ports, the device record, the sync |
| `mc_storage` | `FileStore.readSync` / `writeSync` |
| `mc_ds_theme` | `McTheme.of(variant, visualDensity:)` |
| `app_core` | `McApp` follows the appearance; `McAppearanceFlutter`; `AppearanceDIInitializer` in `rootInitializers`; `AppLocations.settingsAppearance` |
| `mc_test_utils` | The appearance in `McTestContainer` (`appearanceFollowsAccount`, off by default) |

## Follow-ups (for `pending-work.md`)
- `app/sandbox/account_sandbox` (P1-22 lists it; out of scope).
- `settings_home`, the settings index, with a `/settings` parent route.
- DS widgets reading the density themselves.
- The boot page does not follow the saved theme yet.
