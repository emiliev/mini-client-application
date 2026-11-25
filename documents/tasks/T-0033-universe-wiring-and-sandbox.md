# T-0033: `characters_list` in the app: `universe_wiring`, `universe_sandbox`, `mini_client` entry (P1-17 app half)

| Field | Value |
|---|---|
| Status | Ready (dispatch when T-0032's barrel and navigator are final) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh), with iOS simulator e2e |
| Branch | `fleet/T-0033-universe-wiring` |
| Created | 2026-11-25 |
| Depends on | T-0021 (app shell, wirings, `McApp`, `tool/e2e_ios.sh`), T-0032 (`CharactersListFlow`, `CharactersListNavigator`) |
| Related | [plan 01 §3.4, §4.2, P1-17 EX-AC3/EX-AC5](../plan/01-architecture-and-modules.md), R4, R13, R15, R29, ADR-0006 (simulator rules), F-0020, F-0021 |

## Goal
Make the first Marvel feature visible: `characters_list` reachable through typed routes in the real app and in a sandbox app, both on the iOS simulator. Do it the Tide way, with the wiring between them. The feature never knows about routes, and the app never imports a page.

## Scope
- **In:**
  - **`app/wiring/universe_wiring`**, laid out as in plan 01 §3.4:
    - `characters_routes.dart`: a `@TypedGoRoute` tree for `/characters`, with `/characters/:id` as the `CharacterDetailsRoute` placeholder until `characters_details` exists.
    - `route_targets.dart`: the interface.
    - `route_targets_impl.dart`: the unannotated implementation, which builds `CharactersListFlow(navigator: …)` (R15).
    - `CharactersListNavigatorImpl`: `@LazySingleton(as: CharactersListNavigator)` over `GoRouter`, so `openCharacter(id)` pushes `CharacterDetailsRoute(id: id).location`.
    - `UniverseWiringDIInitializer`: injectable, through the T-0028 shim.
    - The test plan 01 §4.2 asks for: `AppLocations.character(id) == CharacterDetailsRoute(id: id).location`.
  - **`app/wiring/app_core`**:
    - `AppLocations.characters` and `.character(id)`.
    - `McMediaScope(resolver: BundledImageResolver())` at the app root, wired through config or DI. Fixtures are only allowed in the backend module and app wiring, never in features or the DS.
  - **`app/mini_client`**:
    - The home page links to "Characters", and `miniclient://app/characters` deep-links there.
    - The 5-tab `StatefulShellRoute` stays out of scope; a plain route is fine for now.
  - **`app/sandbox/universe_sandbox`**:
    - A sandbox app: `McApp(wirings: [universe], fallback: SandboxStubPage)`.
    - Its own bundle id, `com.emiliev.miniclient.sandbox.universe`.
    - It opens on the characters list.
    - A Bazel `flutter_application` target, tagged `manual` like the main app.
- **Out:**
  - `characters_details` (only a placeholder page for `/characters/:id`).
  - The tab shell, auth guard and analytics.

## Acceptance criteria
- **T-0033-AC1:** When the wiring's navigator gets `openCharacter(id)`, then the router's location becomes `CharacterDetailsRoute(id: id).location`, and the placeholder page shows that id. This is a widget test with a real `GoRouter` (EX-AC3, second half).
- **T-0033-AC2:** Given every route in `universe_wiring`, `AppLocations.x(...) == XRoute(...).location`. This is the drift test.
- **T-0033-AC3:** Given `universe_sandbox` on a fresh simulator `mc-T-0033-e2e` (iOS 26.2), when it launches, then the characters list shows real fixture names and art. Evidence: a screenshot of at most 1200 px (EX-AC5).
- **T-0033-AC4:** Given `mini_client` on the simulator, when I tap Characters on home, then the list shows. When I tap a character, the preview opens. When I tap "See full profile", the `/characters/:id` placeholder shows. Evidence: screenshots of each step, from `integration_test` driven by `tool/e2e_ios.sh`. The file-drop link hook is allowed for deep links (F-0020).
- **T-0033-AC5:** `mc_arch_check` passes. The wirings import only feature barrels. No feature or DS package depends on `mc_fixtures_*` (re-run the T-0031-AC6 check). `test //...`, `build --config=lint //...`, `rules_fork.sh check` and `dart format` are green. Both apps build with `tool/bazelw build //app/mini_client //app/sandbox/universe_sandbox`.

## Notes for the Engineer
- Read `CLAUDE.md`, STATUS, the latest journal, `fleet/protocol.md`, plan 01 §3.4 and §4.2, the T-0021 task file and evidence (app shell, `e2e_ios.sh`, the file-drop link), F-0020 and F-0021, and T-0032's Outcome.
- Simulators: create your own (`mc-T-0033-<role>`) and always delete it. Never touch the shared ones (ADR-0006).
- Bazel: always use `tool/bazelw --output_base=/tmp/mc-ob-T-0033-engineer`.
- Commit WIP often. Rebase onto `origin/main` before handoff. Findings start at F-0032; T-0032 starts at F-0031, and the TL renumbers on a clash.

## Log
- 2026-11-25: Created (TL).
- 2026-11-25 (Engineer): built on `c3a5e82` (T-0032 head). Gates, e2e and evidence are in the Outcome below.

## Outcome
**Handed off for verification** on `fleet/T-0033-universe-wiring`. Evidence: [`documents/evidence/T-0033/engineer/`](../evidence/T-0033/engineer/).

### What was built
- **`app/wiring/universe_wiring`** (plan 01 §3.4):
  - `src/routes/characters_routes.dart`: `@TypedGoRoute` tree, `CharactersRoute` (`/characters`) with `CharacterDetailsRoute` (`:id`, an `int`) nested under it, so a deep link builds the back stack list then details. The route file imports only `route_targets.dart` (R15).
  - `route_targets.dart` (interface; each member returns a `*Flow`, which the arch guard demands) and `route_targets_impl.dart` (unannotated, builds `CharactersListFlow(navigator: …)`).
  - `src/flows/character_details_placeholder_flow.dart`: the `/characters/:id` placeholder, shaped as a `*Flow` so the R15 guard passes; `characters_details` replaces it.
  - `CharactersListNavigatorImpl`: `@LazySingleton(as: CharactersListNavigator)` over `GoRouter`; `openCharacter(id)` pushes `CharacterDetailsRoute(id: id.value).location`.
  - `UniverseNavigatorsDIInitializer` (injectable, `di_initializer.dart`) and `UniverseWiringDIInitializer` (the public one: runs the injectable part, then registers `RouteTargetsImpl` by hand, because R15 keeps that file out of the generator's reach).
  - Bazel: go_router_builder and injectable run as actions (F-0007 `sky_engine` dep on both, since the closure now holds Flutter).
- **`app/wiring/app_core`**:
  - `AppLocations.characters` and `.character(int id)`;
  - `RouterRef` + `RouterDIInitializer`: `McApp` only creates its `GoRouter` after boot (R29), so a navigator registered during boot reaches the router through a lazy `GoRouter` registration (`rootInitializers(routerRef:)`, `McApp(routerRef:)`);
  - `McApp(appBuilder:)` and `mediaScopeBuilder`: the app root's `McMediaScope(resolver: BundledImageResolver())`;
  - `appMockDomains` (`CharactersMockDomain`), the only place that imports `mc_fixtures_*` besides the backend;
  - `SandboxStubPage`.
- **`app/mini_client`**: home has a "Characters" button (a `push` to `AppLocations.characters`); `miniclient://app/characters` deep-links to the list; the app passes `appMockDomains`, the router ref and the media scope.
- **`app/sandbox/universe_sandbox`** (new workspace member): `McApp` over `UniverseWiringDIInitializer` alone, opens on the characters list (`/` redirects to it), `SandboxStubPage` for any other route, bundle id `com.emiliev.miniclient.sandbox.universe`, `flutter_application` and `flutter_ios_app` tagged `manual`.
- **e2e**: `tool/e2e/prepare_pub_project.sh` and the apps' `integration_test/` and `test_driver/` (below, F-0032).

### AC → evidence
| AC | Evidence |
|---|---|
| T-0033-AC1 | `//app/wiring/universe_wiring:routes_test`: "T-0033-AC1 the navigator opens CharacterDetailsRoute and the placeholder shows the id" (real `GoRouter`, the generated injectable navigator, the real placeholder; checks `router.state.uri == CharacterDetailsRoute(id: 42).location` and the text `Character details 42`); and "T-0033-AC1 the wiring initializer resolves the route targets and the navigator" |
| T-0033-AC2 | `routes_test`: "T-0033-AC2 every AppLocations entry equals its typed route". It also asserts that the number of `GoRoute`s in `universeRoutes` equals the table's size, so a new route without a row fails |
| T-0033-AC3 | Screenshot [`sandbox/01_sandbox_characters.png`](../evidence/T-0033/engineer/sandbox/01_sandbox_characters.png) from `integration_test/characters_sandbox_test.dart` (names from the fixture package; the test fails unless the first two names, the grid and `Image`s are on screen); [e2e-summary](../evidence/T-0033/engineer/sandbox/e2e-summary.md). Plus `//app/sandbox/universe_sandbox:universe_sandbox_router_test` ("T-0033-AC3": opens on the list; a foreign route shows the stub) |
| T-0033-AC4 | `integration_test/characters_journey_test.dart` through `tool/e2e_ios.sh`: [01_home](../evidence/T-0033/engineer/mini_client/01_home.png), [02_characters_list](../evidence/T-0033/engineer/mini_client/02_characters_list.png), [03_preview](../evidence/T-0033/engineer/mini_client/03_preview.png), [04_full_profile_placeholder](../evidence/T-0033/engineer/mini_client/04_full_profile_placeholder.png) (taps Characters, the first character, "See full profile"; asserts the preview title and `Character details <id from the fixture>`). The deep link: `characters_deeplink_test.dart` (file-drop start link, F-0020) → [05_deep_link_characters](../evidence/T-0033/engineer/mini_client/05_deep_link_characters.png). [e2e-summary](../evidence/T-0033/engineer/mini_client/e2e-summary.md) |
| T-0033-AC5 | `gate-arch.log` (OK; it failed first, which is how the `*Flow` return types came about), `T-0031-AC6_closure.md` (PASS, fixtures dependencies: none in features and DS), `gate-test.log`, `gate-lint.log`, `gate-rules-fork.log`, `gate-format.log`, `gate-app-builds.log` |

### Gates
- `test //...`: 77/77 pass (75 before; +`routes_test`, +`universe_sandbox_router_test`).
- `build --config=lint //...`: clean.
- `run //tool/mc_arch_check:bin`: OK.
- `tool/rules_fork.sh check`: 3 patches apply strictly.
- `dart format --set-exit-if-changed feature utility tool/l10n_check tool/mc_arch_check spike app tool/e2e`: 0 changed.
- `tool/checks/T-0031-AC6_closure.sh`: PASS.
- App builds: `tool/bazelw build --config=sim //app/mini_client:mini_client_ios //app/sandbox/universe_sandbox:universe_sandbox_ios`: OK. The brief's `//app/mini_client //app/sandbox/universe_sandbox` shorthand names no target (neither package has a target of that name; the apps are `:mini_client_ios` and `:universe_sandbox_ios`).
- Merged `origin/main` (0395230, T-0032 merged; no conflicts, lock unchanged by `pub get`) and re-ran every gate and the e2e on the merge result.
- e2e negative control: a wrong expected string exits 1 ([summary](../evidence/T-0033/engineer/e2e-negative-control-summary.md)).
- e2e: all 3 targets PASS on iPhone 17 Pro, iOS 26.2, each run on its own `mc-T-0033-engineer-<pid>` simulator, deleted by `tool/e2e_ios.sh` (0 `mc-T-0033` simulators remain).

### Root and shared changes
- `pubspec.yaml`: workspace member `app/sandbox/universe_sandbox`. `pubspec.lock`: re-resolved with `fvm flutter pub get`; adds `integration_test`, `flutter_driver`, `fuchsia_remote_debug_protocol` (SDK) and `platform`, `process`, `sync_http`, `webdriver`; nothing moved.
- `.gitignore`: `**/.flutter-plugins-dependencies` (written by `pub get` once an app has `integration_test`).
- No existing test was deleted, skipped or weakened; no `// ignore:` added.

### Findings
- [F-0032](../findings/F-0032-e2e-for-a-bazel-only-app.md): how an app with no Xcode project and no committed generated code runs under `tool/e2e_ios.sh`, and why a failing e2e hung until the app's error hooks were handed back.

### Follow-ups for the TL
- `RouteTargets` members must return a `*Flow` (arch guard), so the details placeholder is a `*Flow` too; the interface imports the feature barrel, so the route codegen closure holds Flutter, which is why both actions carry the `sky_engine` dep. Phase D's route bricks should copy this.
- `McApp` has no `localizationsDelegates` yet (F-0031 B3 says the shell needs them once it localises); the flows install their own.
- The e2e prepare step copies the repo and `flutter create`s an Xcode project every run; a cached project would cut the cold build (about 6 min the first time per scratch dir).
- The 5-tab shell, auth guard and analytics stay out of scope, as the task says.
