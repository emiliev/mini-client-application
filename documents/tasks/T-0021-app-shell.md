# T-0021: App shell: `app_core` + `app/mini_client` on the simulator (P1-16, minus the auth guard)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-24; Verifier PASS `47eba5c`) |
| Owner | crew: Engineer (Opus, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0021-app-shell` |
| Created | 2026-11-23 |
| Depends on | T-0017, T-0019, T-0020 |
| Related | [plan 01 §3, §4, P1-16, D-17, D-22](../plan/01-architecture-and-modules.md), [plan 03 §5 iOS app](../plan/03-bazel-integration.md), README R13, R14, R17, R29 (boot and router lifecycle), F-0007 (go_router codegen workaround), P-028 (boot hang), P-031 (Inter in the bundle) |

## Goal
The Tide "glue" app running on the iOS simulator: boot page, DI start-up from the root initializer list, theme from the design system, config from the bundled asset (no dart-defines), go_router with typed routes, and a deep-link-safe boot lifecycle (R29).

## Scope
- **In:**
  - `app/wiring/app_core`: `McApp`, `BootPage` and `BootBloc` (with a timeout and Retry; fixes P-028), the root DI list (`mc_config`, `mc_monitoring`, `mc_event_bus`, `mc_storage`, the mocked-backend wiring), Flutter error hooks into `mc_monitoring`, the theme mode, the `PendingLinks` cold-start link holder, and `AppLocations`.
  - `app/mini_client`: a `flutter_application` plus `flutter_ios_app` (manual, R14) with Inter fonts (P-031) and the `app_config.json` asset from `//tool/bazel/config`. go_router typed routes (go_router_builder plus the F-0007 workaround) with a placeholder home route and a placeholder detail route.
  - 7 empty `*_wiring` skeleton packages (they compile, with no features yet).
  - An e2e smoke journey through `tool/e2e_ios.sh` (simulator screenshots in evidence).
- **Out:** the auth guard (P1-16 AC4, needs `mc_api_auth`), real features.

## Acceptance criteria
- **T-0021-AC1:** Given a failing root initializer, then boot shows an error, and Retry succeeds on the second attempt.
- **T-0021-AC2:** Given boot taking > 10 s (a fake clock in the widget test), then the timeout state shows, with Retry.
- **T-0021-AC3:** Given `xcrun simctl openurl <mc sim> miniclient://app/<placeholder>`, then that route shows (screenshot).
- **T-0021-AC4:** Given a cold-start link while boot is held, when boot succeeds, then that route shows, and no route builder or `redirect` ran before `ready` (counted).
- **T-0021-AC5:** Given the same link and a failing first boot, when Retry succeeds, then the link is replayed once and every root type is registered exactly once.
- **T-0021-AC6:** `tool/bazelw build --config=sim //app/mini_client:mini_client_ios` succeeds and the app launches on a private `mc-T-0021-*` simulator showing the home placeholder in Inter (screenshot). `test //...`, `build --config=lint //...` and `mc_arch_check` pass, and `bazel build //...` performs no `FlutterAotMacho` action (R14).

## Log
- 2026-11-23: Created.
- 2026-11-24 (Engineer): Implemented and rebased on `c9dc283` (T-0023), with `mc_api_client`'s `Dio` wired over the mocked backend. AC1, AC2, AC4, AC5 and AC6 pass. **AC3 is blocked on tooling:** iOS 26.2 answers `simctl openurl miniclient://…` with a system prompt, **Open in “Mini Client”?**, which simctl can't tap ([F-0020](../findings/F-0020-simctl-openurl-confirmation-prompt.md)). The screenshots show the prompt, not the route.
- 2026-11-24 (Engineer, round 2, TL decisions):
  - iOS 18.2 (iPhone SE 3rd gen) shows the same prompt, so the TL amended **AC3**: (a) a widget test that delivers the URI on the platform navigation channel, and the route shows; (b) an on-simulator deep-link screenshot. (b) uses the e2e start-link file `<data>/tmp/mc_e2e_link`, which `main()` reads outside release builds and hands to `PendingLinks`. The real `openurl` e2e is P-042.
  - Rebased on `61373cc` (T-0022). `BootBloc` is now a `McBloc` (events `BootStarted` / `BootRetried`; `BootFailed` is a `McFailureState`, so boot failures reach monitoring).
  - analysis_options: the Flutter packages have none, the same convention as `mc_ds_*`, `mc_fixtures_*` and `spike/hello` (8 of the 9 Flutter packages on main). The root file applies, including its formatter setting; `mc_feature_flow`'s rewritten file is the exception (F-0021).
  - All gates are green; see [evidence/T-0021/engineer/gates.md](../evidence/T-0021/engineer/gates.md).
- 2026-11-24 (Engineer, round 3, `/code-review` fixes):
  1. **Link gap:** `PendingLinks` stays attached until the router's first frame. A post-frame callback then `drain()`s a link caught in between, detaches, and `router.go()`es it. Test T-0021-AC4 (mutation-checked: it fails with the old detach).
  2. **Failure after the timeout** now emits `BootFailed`, which is recorded to monitoring. Test T-0021-AC1.
  3. **Hung boot:** `mc_di` gains `abandonDIContainerInitialization()`. It releases the in-flight guard; the abandoned run never publishes, disposes its staged container when (if ever) its initializer returns, and throws `DIInitializationAbandoned`. Retry from `BootTimedOut` calls it (`McApp.abandonBoot`) and starts a fresh attempt. P-028 is fixed: tests T-0021-AC2 in `boot_test` and `mc_di`. Limit: the stuck initializer's own work can't be cancelled, only discarded.
  4. **Success after the timeout** emits `BootReady`.
  - Nits:
    - `normalise` requires `miniclient://app`, and the router `redirect` sends other schemes and hosts to home;
    - an unknown `backend.scenario` fails boot naming the known ones;
    - `readE2eStartLink` swallows file errors;
    - the warm `openurl` check uses placeholder/43.

## Outcome
**Engineer handoff (2026-11-24, round 2): all six ACs done, AC3 as amended by the TL (F-0020). Real `openurl` e2e → P-042.**

- **`app/wiring/app_core`**
  - `BootBloc`, a `McBloc` from `mc_bloc_kit`, with a 10 s timeout and Retry (fixes P-028). A late result after the timeout still counts. Retry after a timeout abandons the stuck `mc_di` run and starts a fresh one. `McApp` gives the bloc a console `Monitoring` until the root one exists. A failed run is discarded. Retry after a timeout waits for the still-running run instead of starting a second one, because `initializeDIContainer` runs one at a time, and a run that finished late is picked up by Retry.
  - `BootPage` (DS `McLoading` / `McErrorView`).
  - `PendingLinks` (R29), with `offer()` for the e2e start link (`readE2eStartLink`).
  - `McApp`: `MaterialApp(home: BootPage)` until ready, then one `GoRouter` with the held link and `overridePlatformDefaultLocation`; `PendingLinks` detaches only after the router's first frame.
  - `McRouteProbe` (route-build and redirect counter for tests).
  - Flutter error hooks into `Monitoring`.
  - `rootInitializers`: config, monitoring, storage, mocked backend, `ApiClientDIInitializer` over `MockBackendHttpAdapter`, event bus, then the wirings.
  - `appStorageDirectory()` (dart:io only), `AppLocations`.
- **7 `*_wiring` skeletons:** an empty `<g>Routes` and a no-op `<G>WiringDIInitializer` each.
- **`app/mini_client`**
  - Typed routes (`/`, `/placeholder/:id`) through go_router_builder, with the F-0007 `sky_engine` workaround.
  - Not-found page.
  - The `app_config.json` asset, copied from `//tool/bazel/config:app_config`.
  - Info.plist with the `miniclient` scheme and `FlutterDeepLinkingEnabled`.
  - `flutter_ios_app` with bundle id `com.emiliev.miniclient`, `manual`.
- **`mc_di`:** `abandonDIContainerInitialization()` and `DIInitializationAbandoned` (round 3).
- **`mc_ds_theme`:** a `flutter_font_family(":inter")` on the library, so every app bundles `packages/mc_ds_theme/Inter` (fixes P-031).
- **Root edits:** 9 `workspace:` members. The lock is unchanged.
- **Findings:** F-0020 (openurl prompt), F-0021 (`pub get` rewrites Flutter packages' `analysis_options.yaml`, so the new packages have none).
- **Follow-ups for the TL:**
  - P-042: real `simctl openurl` e2e through an XCUITest or Patrol tap on the prompt (F-0020);
  - `tool/ide_sync` for the pub-mode `app_config.json`;
  - add the auth guard to the router's `redirect` with `mc_api_auth`;
  - `tool/loc` on main isn't `dart format`-clean (seen while formatting; left untouched).

## Merge (TL)
- 2026-11-24: **AC3 amended by the TL:** iOS 26.2 and 18.2 both show a confirmation dialog for `simctl openurl` that simctl can't tap (F-0020). AC3 is met by a platform-channel deep-link test plus an R19-style file-drop link screenshot; the real `openurl` e2e is P-042. The TL also approved the `mc_di` `abandonDIContainerInitialization()` API (needed to retry a hung boot, P-028). Verifier PASS `6c625cf` (mutations caught; release binary has no file-drop hook; 0 `FlutterAotMacho` in a cold `build //...`). `/code-review` found 3 important boot-lifecycle issues (a link lost between ready and the router mounting, failure after timeout ignored, Retry unable to escape a hung boot), fixed in `f7a4fe8`. Re-verify PASS `47eba5c`. The TL merged `--no-ff`; on the merge result tests passed 39/39, lint was clean, `mc_arch_check` reported OK and the sim build succeeded.
- Follow-ups: P-042 (real `openurl` e2e via XCUITest or Patrol), P-043 (file-drop hook also active in profile builds; `main.dart` not covered by lint), P-044 (`tool/ide_sync` for `app_config.json` in pub mode; auth guard in the router redirect), P-045 (plan 01 text: DI order and not-found page location).
