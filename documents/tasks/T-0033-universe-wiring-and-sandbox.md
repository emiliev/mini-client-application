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
