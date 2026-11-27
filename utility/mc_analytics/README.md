# mc_analytics

The analytics facade (plan 01 U06, T-0053): typed events, a consent gate, app
sessions, sinks and a screen-tracking route observer. **No third-party SDK and
no network sink**: P-004 needs the Product Owner's sign-off first, so nothing
leaves the device. `test/no_third_party_test.dart` fails on any import outside
the allowed list.

A Flutter package (UF): `AnalyticsRouteObserver` and `AnalyticsLifecycleObserver`
need Flutter. Everything else is plain Dart.

## Why `mc_storage`

Plan 01 lists `mc_prelude`, `mc_di`, `mc_config` and `mc_monitoring`. The consent
choice has to survive a restart, so the package also depends on `mc_storage`
(one key, `analytics_consent`, in the app's `FileStore`). Without it a `denied`
would be forgotten at the next launch.

## The facade

```dart
final analytics = diContainer<Analytics>();
analytics.track(const AnalyticsEvent('comic_opened', params: {'id': 501500}));
analytics.screen('characters_list');
analytics.setUserProperty('plan', 'free');
analytics.reset();                                  // sign-out; the caller decides
await analytics.setConsent(AnalyticsConsent.granted);
analytics.consentChanges;                           // Stream<AnalyticsConsent>
```

### Validation (`AnalyticsRules`)

| Rule | Limit |
|---|---|
| Event name, user-property key, param key | snake_case (`[a-z][a-z0-9]*(_[a-z0-9]+)*`), 1 to 40 characters |
| Params per event | at most 25 |
| Param or property value | `String`, `int`, `double` or `bool` only; a `double` must be finite |
| String value | at most 100 characters (Unicode code points) |
| Reserved name prefixes | `mc_` (the kit's own events), and `ga_`, `firebase_`, `google_` (a future vendor sink) |
| Reserved param keys | `session_id`, `seq`, `screen_name` (the kit adds them) |

A screen name follows the name rules but may start with a reserved prefix. The kit's `screen_name` param counts towards the 25: a screen takes at most 24 params of its own.

An invalid entry is an `AssertionError` in debug mode, so a test fails. Release
mode drops it and reports one `AnalyticsValidationError` per entry to
`Monitoring.recordError`. The mode is `kDebugMode` unless `debugMode:` is
injected (tests of the release path inject `false`). Validation runs whatever
the consent is, so a bug shows in a debug build before anyone has consented.

## The consent gate

| State | `track`, `screen`, `setUserProperty` |
|---|---|
| `unknown` (the default) | buffered in memory, at most **100**; the 101st drops the oldest |
| `granted` | delivered to every sink |
| `denied` | dropped at once |

- `unknown -> granted` flushes the buffer in order. `-> denied` discards it.
  `granted -> unknown` keeps what was queued (trimmed to 100).
- `reset()` (sign-out) starts a new session. Entries already queued with consent `granted` are **kept** and delivered under the session and `seq` they were tracked in (`track(signed_out); reset();` still reports `signed_out`). Only the buffer that waits for a choice (`unknown`) is dropped; with `denied` nothing is queued.
- After `dispose()` every call is a no-op: nothing is tracked, delivered, rotated or saved.
- **Delivery is one microtask later**, never inline, and consent is read again
  for **every** entry at that moment. So `track(e); setConsent(denied)` in the
  same turn delivers nothing, and a sink that denies in the middle of a flush
  stops the rest. `setConsent` changes the state **synchronously**; only the
  saving is asynchronous (the returned future). A test awaits a microtask
  (`await Future<void>.value()`) before it reads a sink.
- Overflow is reported to `Monitoring.trackEvent('analytics_buffer_overflow',
  {dropped, limit})` at the first drop and again, with the total, when consent
  is chosen. `Analytics.droppedCount` totals them.
- The choice is saved in `mc_storage` (`ConsentStore`). A saved choice wins over
  the config default. A damaged or unrecognised saved value gives `unknown`,
  never the default, so a corrupt file cannot turn a `denied` into a grant.
  Boot reads no file when none was saved (F-0038).
- The starting default comes from `AppConfig.analytics.defaultConsent`
  (`tool/bazel/config/<env>.json`): `granted` in `dev` and `e2e` so developers
  see events, absent (`unknown`) in `perf` and any release-like build.

## Sessions

- A session id is 128 random bits as 32 hex characters, from an injectable
  `Random` (`Random.secure()` by default).
- A cold start (a new `Analytics`) always starts a new session. So does
  `reset()`, and so does coming back to the foreground after **30 minutes or
  more** in the background (29:59 keeps it). `paused`, `hidden` and `detached`
  count as background, `inactive` does not. The clock is injectable.
  `AnalyticsLifecycleObserver` maps `AppLifecycleState` to
  `appBackgrounded()` and `appForegrounded()`; `AnalyticsDIInitializer`
  registers it (switch off with `observeLifecycle: false`).
- Each delivered entry carries its session's `sessionId` and a `seq` counted in
  delivery order from 1 with no gaps, also when entries were dropped from the
  buffer. An entry keeps the session it was tracked in, so buffered entries that
  span a rotation are delivered under both ids, each counted from 1.
- The kit emits `mc_session_start` (`reason`: `cold_start`, `timeout`, `reset`)
  when a session begins. `mc_screen_view` (`screen_name`) is a screen.

## Sinks

`AnalyticsSink.record(AnalyticsRecord)`; records are `AnalyticsEventRecord` and
`AnalyticsUserPropertyRecord`.

- `InMemoryAnalyticsSink` for tests and the BDD steps (`events`, `screens`).
- `MonitoringAnalyticsSink` forwards each record to `Monitoring.trackEvent` as
  an `EventEntry` (the params plus `session_id` and `seq`), so a dev build shows
  events in its log. It is the default sink.
- A sink that throws is skipped for that entry and **reported once** (per sink)
  to `Monitoring.recordError`; the other sinks and the app go on.
- `addSink` attaches a recorder to the running app (e2e). It is behind the gate
  like every sink.

## Screens

`AnalyticsRouteObserver` (`GoRouter(observers: [...])`, or
`app_core`'s `appRouterObservers()`) calls `screen()` with each page route's
`settings.name` when it becomes the top route: push, pop, replace or `go`.

- A route with no name, or a name that is not a valid screen name (go_router
  falls back to the path, `/search`), is not tracked. Name every route that is a
  screen: the typed route's `name:`.
- A relative path such as `settings` is a valid name too, so the app passes the
  router's declared `GoRoute.name`s (`screenNames`, `goRouteNames` in
  `app_core`): only a declared name is a screen.
- If `Analytics` is not registered, `appRouterObservers()` tracks nothing and
  navigation goes on.
- Dialogs, sheets and menus are popups, not page routes: ignored.
- The same route becoming the top again with no other page in between (a dialog
  closed over it) is not tracked twice.
- A flow's own navigator (`McFlowPage` names such as `list`, `preview`) has no
  observer, so a flow's inner pages are not tracked yet.

## DI

`AnalyticsDIInitializer` registers `Analytics`. List config, monitoring and
storage first. In `app_core`'s `rootInitializers` it comes right after storage
(plan 01 puts it after monitoring, but it needs the file store). Tests use the
test container, which registers it over the session's `InMemoryAnalyticsSink`.

## BDD steps (`mc_test_steps`)

- `the analytics event {'comic_opened'} was tracked`
- `the analytics event {'comic_opened'} was tracked with` and a `key | json` table
- `no analytics event was tracked` (the kit's own events and screen views excluded)
- `the screen {'characters_list'} was tracked` (it is somewhere in the list)
- `the screens tracked are {'home, characters_list, home'}` (exact, ordered, repeats count)

## Not here

A network or vendor sink (P-004), the privacy settings screen (F060), exposure
events for feature flags (a follow-up once `mc_feature_flags` exists), and
tracking of the pages inside a flow.
