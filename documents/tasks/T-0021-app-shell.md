# T-0021: App shell: `app_core` + `app/mini_client` on the simulator (P1-16, minus the auth guard)

| Field | Value |
|---|---|
| Status | In Progress |
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
- 2026-11-24 (Engineer): Implemented and rebased on `c9dc283` (T-0023), with `mc_api_client`'s `Dio` wired over the mocked backend. AC1, AC2, AC4, AC5 and AC6 pass. **AC3 is blocked on tooling:** iOS 26.2 answers `simctl openurl miniclient://…` with a system prompt, **Open in “Mini Client”?**, which simctl can't tap ([F-0020](../findings/F-0020-simctl-openurl-confirmation-prompt.md)). The screenshots show the prompt, not the route. Gates and the AC map: [evidence/T-0021/engineer/gates.md](../evidence/T-0021/engineer/gates.md).

## Outcome
**Engineer handoff (2026-11-24): AC1, AC2, AC4, AC5 and AC6 done; AC3 blocked (F-0020).**

- **`app/wiring/app_core`**
  - `BootBloc` (a `ChangeNotifier` until `McBloc` lands in T-0022). It has a 10 s timeout and Retry (fixes P-028). A failed run is discarded. Retry after a timeout waits for the still-running run instead of starting a second one, because `initializeDIContainer` runs one at a time, and a run that finished late is picked up by Retry.
  - `BootPage` (DS `McLoading` / `McErrorView`).
  - `PendingLinks` (R29).
  - `McApp`: `MaterialApp(home: BootPage)` until ready, then one `GoRouter` with the held link and `overridePlatformDefaultLocation`.
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
- **`mc_ds_theme`:** a `flutter_font_family(":inter")` on the library, so every app bundles `packages/mc_ds_theme/Inter` (fixes P-031).
- **Root edits:** 9 `workspace:` members. The lock is unchanged.
- **Findings:** F-0020 (openurl prompt), F-0021 (`pub get` rewrites Flutter packages' `analysis_options.yaml`, so the new packages have none).
- **Follow-ups for the TL:**
  - an XCUITest or Patrol tap for system alerts, to close AC3 (F-0020);
  - port `BootBloc` onto `McBloc` after T-0022;
  - `tool/ide_sync` for the pub-mode `app_config.json`;
  - add the auth guard to the router's `redirect` with `mc_api_auth`;
  - `tool/loc` on main isn't `dart format`-clean (seen while formatting; left untouched).
