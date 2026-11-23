# T-0021: App shell: `app_core` + `app/mini_client` on the simulator (P1-16, minus the auth guard)

| Field | Value |
|---|---|
| Status | Ready (dispatch after T-0020 merges) |
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

## Outcome
_Pending._
