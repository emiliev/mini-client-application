# Verification report: T-0033, `characters_list` in the app (universe_wiring, universe_sandbox, mini_client entry)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-25
- **Branch / commit verified:** `fleet/T-0033-universe-wiring` @ `7ab4924a9258188b0622b4f65eae26c23c6e5a08` (detached, own worktree)
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0033-verifier …` (shut down at the end)
- **Simulators:** created and deleted by `tool/e2e_ios.sh` for each run, named `mc-T-0033-verifier-<pid>` (the script appends the pid): `-38589` (sandbox), `-39808` (mini_client), plus one each for the negative control and the back probe. iPhone 17 Pro, iOS 26.2. `xcrun simctl list devices | grep -c mc-T-0033` → `0` afterwards. No shared simulator was touched.
- **Verdict:** **PASS** on all five ACs. There are two **major** defects in the tooling and evidence around the ACs (D1, D2), and the TL should route both before or right after the merge. See "Issues found".

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| L1–L3 Tests | `tool/bazelw … test //...` | **77/77 pass** ([log](verifier/logs/gate-test.log)) |
| New targets, uncached | `tool/bazelw … test --nocache_test_results //app/...` | **5/5 pass**: `routes_test` (3 cases), `universe_sandbox_router_test` (2), `app_test`, `boot_test`, `links_and_hooks_test` ([log](verifier/logs/gate-test-app-uncached.log)) |
| L0 Lint | `tool/bazelw … build --config=lint //...` | clean ([log](verifier/logs/gate-lint.log)) |
| L0 Arch | `tool/bazelw … run //tool/mc_arch_check:bin` | `mc_arch_check: OK` ([log](verifier/logs/gate-arch.log)) |
| Rules fork | `tool/rules_fork.sh check` | 3 patches apply strictly; flutter queue empty ([log](verifier/logs/gate-rules.log)) |
| L0 Format | `fvm dart format --output=none --set-exit-if-changed feature utility tool/l10n_check tool/mc_arch_check spike app tool/e2e` | 382 files, **0 changed**. This needs `fvm flutter pub get` first: without a package config the root `formatter: trailing_commas: preserve` can't be read, and 18 files "change" (F-0021). `pub get` left the tree clean, so the lock is consistent |
| T-0031-AC6 | `MC_OUTPUT_BASE=… tool/checks/T-0031-AC6_closure.sh` | PASS ([log](verifier/logs/ac6.log)), but it covers DS packages only (D2) |
| App builds | `tool/bazelw … build --config=sim //app/mini_client:mini_client_ios //app/sandbox/universe_sandbox:universe_sandbox_ios` | OK ([log](verifier/logs/gate-app-builds.log)). The sandbox `.ipa`'s `CFBundleIdentifier` is `com.emiliev.miniclient.sandbox.universe`. The AC's shorthand `//app/mini_client //app/sandbox/universe_sandbox` names no target (`no such target …:universe_sandbox`), as the engineer reported |
| L4 E2E sandbox | `tool/e2e/prepare_pub_project.sh` + `tool/e2e_ios.sh --task T-0033 --role verifier --project <scratch>/app/sandbox/universe_sandbox` | **PASS**, 1 target, 31 s ([summary](verifier/sandbox/e2e-summary.md)). Needs the D1 workaround |
| L4 E2E mini_client | same, `--project <scratch>/app/mini_client` | **PASS**, 2 targets: journey 28 s, deep link 40 s ([summary](verifier/mini_client/e2e-summary.md)) |
| E2E negative control | journey copy expecting `Character details ${first.id + 1}`, with a 600 s watchdog | **exit 1 after 58 s** (target 36 s); `Expected: exactly one matching candidate … Found 0 widgets`. The watchdog never fired ([summary](verifier/negative_control/e2e-summary.md), [run](verifier/logs/negative-control-run.out)) |
| Coverage | n/a | No domain, data or backend code in this task |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Does the test really assert the AC? | Result |
|---|---|---|---|---|
| T-0033-AC1 | `openCharacter(id)` → location `CharacterDetailsRoute(id).location`, and the placeholder shows the id | `//app/wiring/universe_wiring:routes_test`: "T-0033-AC1 the navigator opens CharacterDetailsRoute and the placeholder shows the id"; "T-0033-AC1 the wiring initializer resolves the route targets and the navigator" | **Yes.** It uses a real `GoRouter` over `universeRoutes`, the injectable-generated `CharactersListNavigatorImpl` (through `UniverseNavigatorsDIInitializer` + `RouterDIInitializer`), and the real placeholder flow. The list flow is faked. It asserts `router.state.uri == CharacterDetailsRoute(id: 42).location`, the placeholder key and `Character details 42`. Mutations M1, M3 and M4 kill it. M2 (`go` instead of `push`) survives (D3) | PASS |
| T-0033-AC2 | `AppLocations.x(...) == XRoute(...).location` for every route | `routes_test`: "T-0033-AC2 every AppLocations entry equals its typed route" | **Yes.** It compares a 2-row table and asserts that the number of `GoRoute`s in `universeRoutes` equals the table size. Killed by M5a (an untyped `GoRoute` added to `universeRoutes`), M5b (a new nested `@TypedGoRoute` `CharacterSearchRoute` with no row), M6a (`AppLocations.character` → `/character/$id`) and M6b (`AppLocations.characters` → `/characters/`). Limitation: the count check doesn't catch "add a route and replace a row" | PASS |
| T-0033-AC3 | `universe_sandbox` on a fresh sim opens on the list with real fixture names and art | `integration_test/characters_sandbox_test.dart` "T-0033-AC3 …" (on the sim) + `universe_sandbox_router_test` (2 × "T-0033-AC3": `/` redirects to the list; a foreign route shows `SandboxStubPage`) + screenshot | **Yes.** The names come from `CharacterUniverse(42, …).byName`. The test finds the first two names, the grid key and `Image` widgets, then waits 3 s for the art. The screenshot shows the art | PASS |
| T-0033-AC4 | home → Characters → list → tap → preview → "See full profile" → `/characters/:id` placeholder; deep link `miniclient://app/characters` | `integration_test/characters_journey_test.dart` "T-0033-AC4 home to the characters list, a preview, the full profile placeholder"; `characters_deeplink_test.dart` "T-0033-AC4 the deep link miniclient://app/characters opens the list" (file drop, F-0020) | **Yes.** It runs through the real `main()`, taps by text and asserts each step: the preview title equals the first name, and the placeholder shows `Character details <fixture id>`. The deep-link test asserts the grid and no home. The negative control proves the test can fail (exit 1, 58 s) | PASS |
| T-0033-AC5 | arch check, barrel-only wirings, no fixtures in feature/DS, gates green, both apps build | Gate logs (above). There is no `T-0033-AC5`-named check; this is a gates-only AC | `mc_arch_check` OK. Every app import of the feature is `package:characters_list/characters_list.dart` (6 imports, no `src/`). DS: the T-0031-AC6 check passes. Features: **the T-0031-AC6 check does not look at them** (the negative control still passes, D2). My own `deps()` scan of all 24 production libraries under `//feature` and `//utility` finds **0** fixtures dependencies, and its positive control (the same injected dependency) is a HIT. The only production `lib/` import of `mc_fixtures_*` outside the fixtures packages is `app/wiring/app_core/lib/src/media/app_media.dart` (app wiring, allowed); everything else is `test/` or `integration_test/` | PASS (property holds; the cited evidence is insufficient: D2) |

## Mutations (each restored from a backup; `git status` clean after each)
| ID | Mutation | Run | Result |
|---|---|---|---|
| M1 | `CharacterDetailsRoute(id: id.value + 1)` in the navigator | `routes_test` | **killed** (AC1 case 1 FAIL) |
| M2 | `go` instead of `push` (`unawaited(Future.sync(() => _router.go(…)))`) | `routes_test`, then `//app/...` | **survives**: all 5 app tests pass (D3). A bare `_router.go` inside `unawaited` doesn't compile (`go` returns `void`), so M2 kept `dart:async` in use |
| M3 | navigator pushes `const CharactersRoute().location` | `routes_test` | **killed** |
| M4 | placeholder shows `${id + 1}` | `routes_test` | **killed** |
| M5a | `GoRoute(path: '/teams', redirect: …)` added to `universeRoutes` | `routes_test` | **killed** (AC2 FAIL) |
| M5b | new `TypedGoRoute<CharacterSearchRoute>(path: 'search')`, no table row | `routes_test` | **killed** (`Expected: an object with length of <2>`) |
| M6a | `AppLocations.character` → `'/character/$id'` | `routes_test` | **killed** |
| M6b | `AppLocations.characters` → `'/characters/'` | `routes_test` | **killed** |
| F1 | `"//utility/mc_fixtures_media"` added to `characters_list`'s `_FLUTTER_DEPS` | `tool/checks/T-0031-AC6_closure.sh` | **survives**: PASS, `fixtures dependencies: none` ([log](verifier/logs/ac6-neg.log), D2) |
| F1' | same | my scan ([script](verifier/logs/fixtures_scan.sh.txt)) | **caught**: `HIT //feature/characters/characters_list:characters_list -> //utility/mc_fixtures_media:…` |

Logs: `verifier/logs/mut-*.log`.

## Back navigation (AC4 extra), on the simulator
A probe target in the scratch copy only ([source](verifier/back_probe/verifier_back_probe_test.dart.txt), [log](verifier/back_probe/e2e-verifier_back_probe_test.log)), run through the real `main()`:

```
PROBE list:                         home=0 grid=1 preview=0 placeholder=0 backButtons=0
PROBE preview:                      home=0 grid=0 preview=1 placeholder=0 backButtons=1
PROBE placeholder:                  home=0 grid=0 preview=0 placeholder=1 backButtons=1
PROBE after back from placeholder:  home=0 grid=0 preview=1 placeholder=0 backButtons=1
PROBE after second back:            home=0 grid=1 preview=0 placeholder=0 backButtons=0
PROBE system back handled=true
PROBE after system back:            home=1 grid=0 preview=0 placeholder=0 backButtons=0
```
- Back from the placeholder returns to **the preview, with the same character** ([probe_01](verifier/back_probe/probe_01_after_back_from_placeholder.png)). Back again returns to the list ([probe_02](verifier/back_probe/probe_02_after_second_back.png)).
- The list, pushed over home, has **no back button** (D5). Only a system pop returns home ([probe_03](verifier/back_probe/probe_03_after_system_back.png)).

## Design review
- **`RouterRef` + `RouterDIInitializer` (`app_core/lib/src/router/router_ref.dart`).** This fits R29: the root container is published once during boot, but the `GoRouter` exists only after `ready`. A lazy `GoRouter` registration that reads a ref `McApp` fills in is the smallest bridge that doesn't re-register into the published container.
  - **Failing early is clear.** A probe test, appended temporarily to `routes_test` and then removed ([log](verifier/logs/probe-routerref.log)), called `openCharacter` before `attach`. It got `StateError: Bad state: The router does not exist yet: it is created when boot is ready, so a navigator may only be used from a route or a callback.`
  - **It recovers.** get_it doesn't cache a throwing lazy factory, so the navigator resolves once the router is attached.
  - Caveats (minor): `rootInitializers(routerRef:)` is optional, and an app that forgets it gets get_it's generic "GoRouter not registered" on first navigation. The lazy `GoRouter` singleton also caches the first router, so a second `McApp` with a new router in the same container would keep the old one. Neither happens in the apps today.
- **`CharacterDetailsPlaceholderFlow`.** It lives in **`app/wiring/universe_wiring/lib/src/flows/character_details_placeholder_flow.dart`** and is exported from the **universe_wiring** barrel (`universe_wiring.dart:10-11`), **not** from `characters_list`'s barrel. So R4 is not violated, and the feature barrel is unchanged.
  - It is a plain `StatelessWidget` whose name ends in `Flow`, so that `RouteTargets.characterDetails` satisfies the R15 guard. The guard only checks the suffix. That is acceptable as a temporary stand-in until `characters_details` exists, but Phase D generators must not copy it as a pattern.
  - The wiring barrel exports more than plan 01 §3.4 lists (`universeRoutes`, `UniverseWiringDIInitializer`): it adds `RouteTargets`, the route classes, the placeholder and `UniverseNavigatorsDIInitializer`. The extras serve the tests and `AppLocations` parity. This is minor and the TL's call.
  - The route `build`s use `diContainer<RouteTargets>()` instead of plan §4.2's `RouteTargets.of(context)`. That is app-layer code, so it is allowed.

## `tool/e2e/prepare_pub_project.sh`
- **Working tree untouched: yes.** `git status --porcelain --ignored` was empty before. After both prepares it shows only Bazel's own `bazel-*` convenience links.
- **Scratch dir:** a non-empty `--out` is refused (`… is not empty`, exit 2), so a dir is never reused, safely or not. The script never deletes the dir; the caller owns cleanup. Xcode's DerivedData is keyed by path, so reusing the same scratch path gives warm builds.
- **Stale or missing generated files (D1).** The script copies *every* `*.g.dart`, `*.freezed.dart`, `*.config.dart` and l10n file under `bazel-bin/{app,feature,utility}`, regular files and symlinks alike.
  1. **On a fresh output base it fails.** Bazel 9 with the shared `--disk_cache` defaults to `--remote_download_outputs=toplevel`, so most generated files are never materialised in `bazel-bin` (1 regular `.g.dart` of about 36 needed). `cp -L` then stops on a dangling symlink inside a `*.pkg_roots.*` or `*.summary_root` tree, with exit 1. Reproduced twice, on `/tmp/mc-ob-T-0033-verifier` and on a throw-away `…-fresh` base ([log](verifier/logs/prep-fresh-ob.log)). Running `build --remote_download_outputs=all` for the two `_lib` targets first fixed it (`prep-mini.log`, `prep-sandbox.log`). The engineer's run only worked because their output base already held local outputs. A missing regular file (as opposed to a dangling link) would fail later still, as a compile error in `flutter drive`.
  2. **It copies junk.** 136 of the 172 files copied for `mini_client` are `*.pkg_roots.*` and summary-tree copies, dropped at paths such as `app/mini_client/app_routes_go_router_part.pkg_roots.eee…/…`. They are harmless outside `lib/`, but they inflate F-0032's "212 generated files".
  3. **Staleness.** Files in `bazel-bin` that the target's closure doesn't rebuild (orphans from other branches or deleted sources) are copied too. Today they can't reach the compile, because pub resolution only compiles what is imported. Restricting the copy to the target's own outputs (or `cquery --output=files`) would remove the risk.

## Test-integrity audit
- **Tests deleted, skipped or weakened: none.** `boot_test.dart`, `links_and_hooks_test.dart` and `app_test.dart` changed, but compared ignoring whitespace and trailing commas they are identical to `origin/main`. This is **format-only churn** (D6), probably from a `dart format` run without the package config.
- **Lint suppressions added: none.** No `// ignore:` and no `skip:`. The `no-dart-analyze` / `no-dart-format` tags appear only on the codegen-only `_stage` target, whose files are analysed in the main library. That follows the `characters_list` precedent.
- **Golden files updated:** none.
- **Locks:**
  - `pubspec.lock` adds only `integration_test`, `flutter_driver` and `fuchsia_remote_debug_protocol` (SDK) plus `platform`, `process`, `sync_http` and `webdriver`.
  - In `MODULE.bazel.lock`, a structural JSON diff shows only new `pub_deps*` repos for those packages and updated `lock_packages` lists. No existing version or sha256 changed.
- **`.gitignore`** adds `**/.flutter-plugins-dependencies`, but `app/sandbox/universe_sandbox/.flutter-plugins-dependencies` was committed in 7868684, before the ignore. It is still tracked and carries absolute `/Users/…/fvm/…` paths plus a timestamp (D4).
- **Unrelated changes:** none besides D6.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| AC3 sandbox | [`verifier/sandbox/01_sandbox_characters.png`](verifier/sandbox/01_sandbox_characters.png) | "Characters" title, 2-column grid: Amber Alchemist, Amber Artisan, Amber Bard, Amber Beacon, with gradient silhouette art; third row partly visible; no back button | yes |
| AC4 home | [`verifier/mini_client/01_home.png`](verifier/mini_client/01_home.png) | "Mini Client" home placeholder, `Config: env=e2e`, red **Characters** button above "Open placeholder 7" | yes |
| AC4 list | [`verifier/mini_client/02_characters_list.png`](verifier/mini_client/02_characters_list.png) | same grid as the sandbox, art loaded; no back arrow | yes |
| AC4 preview | [`verifier/mini_client/03_preview.png`](verifier/mini_client/03_preview.png) | back arrow, title "Amber Alchemist", large art, red "See full profile" | yes |
| AC4 placeholder | [`verifier/mini_client/04_full_profile_placeholder.png`](verifier/mini_client/04_full_profile_placeholder.png) | back arrow, "Character 100486", "Character details 100486", "The full profile arrives with characters_details." | yes |
| AC4 deep link | [`verifier/mini_client/05_deep_link_characters.png`](verifier/mini_client/05_deep_link_characters.png) | the characters grid as the start screen (no home) | yes |
| Back probe | `verifier/back_probe/probe_0{1,2,3}_*.png` | the preview again, then the list, then home after a system pop | n/a (extra) |

All screenshots are 552×1200. The script downscaled them from 1206×2622.

**Visual nit (cards' empty area).** Each card shows roughly 3 text lines of empty space under a 1-line name. This is the **DS default**:
- The feature sizes cells with `McMediaCard.heightFor` (`characters_list_page.dart:61`), which always reserves a **2-line title + 1-line subtitle** (`utility/mc_ds_cards/lib/src/mc_media_card.dart:51-64`). The card's text block is `Expanded` (`:84`), so it fills that reserve.
- The feature passes no `subtitle` (`character_tile.dart:15-21`).
- Route it to the **DS** (`mc_ds_cards`: let `heightFor` take `hasSubtitle` / `titleLines`), and optionally to the feature if a subtitle such as the comics count is wanted. It is not a T-0033 problem.

## Issues found
1. **D1 (major) `tool/e2e/prepare_pub_project.sh:54,72-74`: fails from a fresh output base.** With the shared disk cache, Bazel downloads only top-level outputs, so the generated files aren't in `bazel-bin`, and the copy dies on a dangling symlink in a `*.pkg_roots.*` or `*.summary_root` tree.
   - Repro: `MC_OUTPUT_BASE=/tmp/new-ob tool/e2e/prepare_pub_project.sh --app app/sandbox/universe_sandbox --out /tmp/x` exits 1 with `cp: …/universe_wiring.dart_analyzer_summary.summary_root/lib/src/di/di_initializer.config.dart: No such file or directory`.
   - Fix: build with `--remote_download_outputs=all`, or `--remote_download_regex` for generated suffixes. Copy only the target closure's generated outputs, and exclude `*.pkg_roots.*` and `*.summary_root`.
   - F-0032's "212 generated files" and "the working tree is not touched / then runs unchanged" should say this.
2. **D2 (major) `tool/checks/T-0031-AC6_closure.sh:35-40` checks only `//utility/mc_ds_*`.** AC5's "no **feature** … depends on `mc_fixtures_*`" is therefore unproven by the cited check, and the task Outcome (`T-0033-…md:85`, "none in features and DS") overclaims.
   - Negative control F1 (a fixtures dependency in `characters_list`) still PASSes.
   - The property does hold at 7ab4924 (my `deps()` scan of 24 libraries, with a positive control).
   - Fix: add a `//feature/...` production-library clause, with a positive control, to the check or to a `T-0033-AC5` check.
3. **D3 (minor) `characters_list_navigator_impl.dart:17` / `routes_test.dart:63-74`: `push` isn't locked by any test.** The scope says "pushes", and back-to-preview depends on it.
   - At HEAD the behaviour is right: the on-sim probe confirms back returns to the preview.
   - Mutation M2 (`go`) survives every app test. Suggest asserting `router.canPop()` and that a pop returns to the list after `openCharacter`.
4. **D4 (minor) `app/sandbox/universe_sandbox/.flutter-plugins-dependencies` is tracked.** It is a generated file ("do not … check into version control") containing absolute local paths. Fix: `git rm --cached`; the new `.gitignore` line then covers it.
5. **D5 (minor, out of scope; route to `mc_feature_flow` / `characters_list`) No back button on the list when it is pushed from home.** The flow's nested Navigator makes the list page its own root, so `AppBar` (`characters_list_page.dart:47`) doesn't imply a leading back. Only a system pop returns home, and iOS has no system back key.
6. **D6 (minor) Format-only churn in 3 existing tests.** These are `app/wiring/app_core/test/boot_test.dart`, `links_and_hooks_test.dart` and `app/mini_client/test/app_test.dart`, all unrelated to the task (verified token-identical). They still pass the format gate with the config loaded.
7. **D7 (minor) AC5 has no `T-0033-AC5`-named check.** ADR-0006 §1 asks for one per AC. The evidence is gate logs only.

## Notes for the Tech Lead
- To re-run the e2e path until D1 is fixed, first run `tool/bazelw --output_base=<ob> build --remote_download_outputs=all //app/mini_client:mini_client_lib //app/sandbox/universe_sandbox:universe_sandbox_lib`, then `prepare_pub_project.sh`.
- `tool/e2e_ios.sh` still has no per-target timeout. The 7ab4924 handback (`startApp` saves `FlutterError.onError` and `PlatformDispatcher.onError`, runs `main()`, then restores them) is correct: `installErrorHooks` (`app_core/lib/src/shell/error_hooks.dart:29-30`) is the only production writer, and it runs synchronously inside `main()`. But any future boot-time hook install would bring the hang back. A watchdog in `e2e_ios.sh` would make that fail bounded.
- The scratchpad e2e copies (with the probe and negative-control targets) live outside the repo. Nothing in the repo was changed beyond this report and `documents/evidence/T-0033/verifier/`.

---

## Re-verification at 61535d2

- **Commit verified:** `fleet/T-0033-universe-wiring` @ `61535d2` (detached, own worktree), on top of 51e1c1a. T-0034 is not on this branch and was not verified.
- **Bazel:** `/tmp/mc-ob-T-0033-verifier`, wiped before the e2e prepares and shut down at the end. `T-0033-e2e_prepare.sh` used its own throw-away base, `/tmp/mc-ob-T-0033-verifier-fresh`, which it wiped and deleted.
- **Simulators:** each was created and deleted by `tool/e2e_ios.sh`: `mc-T-0033-verifier-69243` (sandbox), `-74006` (mini_client), `-85079` and `-86869` (warm-link probes) and `-87975` (mini_client warm-link probe from the list). None was left over from before the stop. `xcrun simctl list devices | grep -c mc-T-0033` → `0`.
- **Verdict:** **FAIL**, on one blocker (R1). The fix round itself is good: every item the engineer claims is verified below, and all five T-0033 ACs still pass as written. R1 is a regression that the fix round's sandbox link tests can't see: once `characters_list`'s flow has mounted, **every deep link that arrives while the app runs is dropped**, in both apps. This breaks T-0021-AC3's behaviour in the real app. The TL can waive R1 for a follow-up, but it is not something to merge silently.

### R1 (blocker): live deep links die once a `FeatureFlow` has mounted (flow_builder 0.1.0)
- **Symptom on the simulator** (the real `main()`, links delivered as the iOS embedder delivers them: a `pushRouteInformation` call on `flutter/navigation`):
  - **mini_client** ([log](verifier/reverify/warm_probe_mini/e2e-verifier_warm_link_test.log)):
    - `miniclient://app/placeholder/42` from home works, and so does `miniclient://app/characters/6`, which builds the list flow under the details page.
    - After that, `miniclient://app/characters`, `miniclient://app/placeholder/43` and `miniclient://app/characters/8` all leave the location at `…/characters/6` ([screenshot](verifier/reverify/warm_probe_mini/rv_07_mini_warm_probe_from_list.png): still "Character details 6").
  - **sandbox**, which opens on the list ([log](verifier/reverify/warm_probe_sandbox/e2e-verifier_warm_own_link_test.log)): `miniclientuniverse://app/characters/6` and even the plain path `/characters/7` leave the location at `/characters`. My first sandbox probe (`verifier_foreign_link_test`) timed out waiting for "details 6" after a warm own-scheme link, which is how I found this.
- **Reproduced under Bazel.** A temporary case appended to `app_test` and then removed ([log](verifier/reverify/logs/rv-probe-flowbuilder.log)) booted the real app with `roots()` and pushed `placeholder/41` (shown), then `/characters` (grid shown), then `placeholder/43`. It printed `before-flow link shown=1 grid=1 after-flow link shown=0`.
- **Root cause:** `flow_builder-0.1.0/lib/flow_builder.dart`.
  - `FlowBuilder.initState` (`:104`) calls `_SystemNavigationObserver.add`, which **replaces the framework's `flutter/navigation` handler** (`:350`, `SystemChannels.navigation.setMethodCallHandler(_handleSystemNavigation)`).
  - The replacement handles only `popRoute` and `pushRoute`. Its `default:` case drops `pushRouteInformation`, which is what the iOS embedder sends for deep links (`:357-365`).
  - `remove` (`:143`) never restores the handler, so the breakage lasts for the rest of the process.
  - Cold-start links (`defaultRouteName`) and links held during boot are not affected.
- **Why the fix-round tests pass:** `universe_sandbox_links_test` uses `FakeTargets`, whose list is a `SizedBox`, so no `FlowBuilder` ever mounts. "a sandbox link that arrives after boot opens its route" is therefore true in the test and false in the app.
- **Where it belongs:** `mc_feature_flow`, or a rules/pub patch of flow_builder.
  - Possible fixes: handle `pushRouteInformation` and every other method by delegating to the framework, and restore the previous handler on `remove`. Or don't use flow_builder's system-navigation interceptor at all.
  - Pin it with a test that mounts a real `FeatureFlow`, then pushes a link.
  - F-0018 doesn't mention this, so it should get a finding.
  - It isn't T-0033's code, but T-0033 is the first task to put a `FlowBuilder` into the app, so the merge would introduce the regression.

### Fix-round items
| # | Item | What I ran | Result |
|---|---|---|---|
| 1 | Sandbox deep links: `LinkScheme`, sandbox `miniclientuniverse://app`, router guard | `//app/sandbox/universe_sandbox:universe_sandbox_links_test` (5) + `//app/wiring/app_core:router_ref_and_scheme_test` (2 scheme cases), uncached | **7/7 PASS** ([log](verifier/reverify/logs/rv-gate-test-app.log)) |
| | mutations | L1: drop `scheme.isForeign(uri)` from `buildSandboxRouter`'s redirect · L2: `installSandboxLinks` without `scheme:` | L1 **killed** ("a foreign link that arrives after boot is ignored"); L2 **killed** (3 cases) |
| | **cold start on the sim**, `miniclientuniverse://app/characters/5` | probe `verifier_cold_link_test`: sets `PlatformDispatcher.defaultRouteName` (where the iOS embedder puts the cold-start route) and runs the real `main()`. The sandbox's `main()` has no file-drop hook | **PASS**: [details placeholder 5](verifier/reverify/sandbox/rv_01_sandbox_cold_link_details_5.png) |
| | **foreign scheme refused on the sim** | probe `verifier_foreign_link_test`: cold start with `miniclient://app/characters/5`, then live `miniclient://app/…`, `https://example.com/…` and `miniclientuniverse://other/…` | cold: **refused**, the [list](verifier/reverify/sandbox/rv_02_sandbox_cold_foreign_link_list.png) opens. Live: no details shown, but that proves nothing, because live links are dropped anyway (R1). The probe's final own-scheme step failed on R1 |
| 2 | D1 `prepare_pub_project.sh` | `MC_FRESH_OUTPUT_BASE=/tmp/mc-ob-T-0033-verifier-fresh tool/checks/T-0033-e2e_prepare.sh` | **PASS** ([report](verifier/reverify/T-0033-e2e_prepare.md)): from a wiped base, 6 targets, 18 generated files, exactly the listed outputs; the planted stale `stale_planted.g.dart` was not copied; **both negatives FAILED as they must**. `git status --porcelain --ignored`: **identical** before and after |
| | my own prepares | wiped `/tmp/mc-ob-T-0033-verifier`, then prepared both apps | mini_client 18 and sandbox 17 files; exit 0 ([logs](verifier/reverify/logs/)). My part-file scan of the copy: **0 missing**. My worktree has ignored, pub-generated l10n files from an earlier `pub get`; they weren't copied (git's list), and both apps compiled and ran |
| 3 | D2 closure check | `tool/checks/T-0031-AC6_closure.sh` | **PASS**, with **23** production feature and utility targets (`characters_list` included). Its built-in negative is reported ([log](verifier/reverify/logs/rv-ac6.log)) |
| | my negative | `//utility/mc_fixtures_media` in `characters_list`'s `_FLUTTER_DEPS` | **FAIL T-0031-AC6**, exit 1 ([log](verifier/reverify/logs/rv-ac6-neg.log)): fixed |
| 4 | D3 push lock | mutation `push` → `go` | **killed**: "T-0033-AC1 the navigator pushes: Back returns to the list…" FAILs |
| 5 | D4 | `git ls-files \| grep -c flutter-plugins-dependencies` | `0`: fixed |
| 6 | D6 | `git diff origin/main..HEAD --stat` on the 3 files | `boot_test.dart` and `links_and_hooks_test.dart` are **identical** to `origin/main`; `app_test.dart` +28/−5, only item 7's `roots()` signature, `appMockDomains` and `routerRef`, plus the new T-0033-AC4 case. No assertion weakened |
| 7 | D7 `T-0033-AC5_gates.sh` | positive run | **PASS** (8 gates; 79 tests) ([report](verifier/reverify/T-0033-AC5_gates.md)) |
| | `MC_GATES_NEGATIVE=1` | built-in negative | the fixtures gate **FAILs** and the script reports "caught" (exit 0 by design: it inverts) ([report](verifier/reverify/T-0033-AC5_gates_negative.md)). Narrow: it plants only the fixtures dependency |
| | my negative | an unformatted file planted in `universe_wiring/lib/src/`, full run | script **exit 1**: test, lint and format FAIL ([report](verifier/reverify/T-0033-AC5_gates_planted_format_violation.md)); file removed |
| 8a | `roots()` boots like production | temporary `app_test` case: boot with `roots()`, tap Characters | `location=/characters grid=1 amber=6`: the real list loads from the mocked backend ([log](verifier/reverify/logs/rv-probe-roots.log)) |
| 8b | `RouterRef.detach` | `router_ref_and_scheme_test` (3 AC1 cases) PASS. Temporary `routes_test` case: attach r1, resolve the navigator, detach and dispose r1, attach r2, `openCharacter(9)` | **R2 (minor):** the `GoRouter` factory never hands out a detached router. But `CharactersListNavigatorImpl` is a `@LazySingleton` that captured r1 in its constructor, so the same instance comes back and pushes to the disposed router ("A GoRouteInformationProvider was used after being disposed"; r2 stays at `/characters`) ([log](verifier/reverify/logs/rv-probe-detach.log)). No production path disposes `McApp`, so this is minor. Fix: navigators read the router per call (inject `RouterRef` or a `GoRouter Function()`), or register as factories |
| 8c | `mc_e2e_utils` | `query attr(testonly,1,…)`; `rdeps(//..., mc_e2e_utils)`; `deps()` of both `*_ios` apps | **testonly**; no reverse dependency but itself; 0 hits for `mc_e2e_utils`, `integration_test` or `flutter_driver` in either app's closure; only `dev_dependencies` and `integration_test/` import it |
| 9 | Full e2e on my sims | `tool/e2e_ios.sh` on both prepared projects | mini_client **PASS** (journey 26 s, deep link 34 s) ([summary](verifier/reverify/mini_client/e2e-summary.md)); sandbox target `characters_sandbox_test` **PASS** (35 s). The sandbox run's FAIL is my own probe hitting R1 ([summary](verifier/reverify/sandbox/e2e-summary.md)) |
| 10 | Gates | `test //...` + `test --nocache_test_results //app/... //utility/mc_e2e_utils/...`; plus `T-0033-AC5_gates.sh` (lint, arch, rules_fork, format, l10n_check, closure, both `--config=sim` builds) | **79/79**; the 7 app targets uncached PASS; all 8 gates PASS |
| | sample mutations | M1 wrong id, M3 wrong route, M5a untabled route, M6a path change | all **killed** ([logs](verifier/reverify/logs/)) |

### Screenshots (all 552×1200, viewed)
| File | What is visible |
|---|---|
| `reverify/mini_client/01_home.png` | home placeholder, `Config: env=e2e`, **Characters** and "Open placeholder 7" buttons |
| `reverify/mini_client/02_characters_list.png` | "Characters" grid: Amber Alchemist / Artisan / Bard / Beacon with art |
| `reverify/mini_client/03_preview.png` | back arrow, "Amber Alchemist", art, "See full profile" |
| `reverify/mini_client/04_full_profile_placeholder.png` | "Character 100486" / "Character details 100486" |
| `reverify/mini_client/05_deep_link_characters.png` | the grid as the start screen (file-drop cold link) |
| `reverify/sandbox/01_sandbox_characters.png` | the sandbox opens on the same grid with art |
| `reverify/sandbox/rv_01_sandbox_cold_link_details_5.png` | back arrow, "Character 5" / "Character details 5" |
| `reverify/sandbox/rv_02_sandbox_cold_foreign_link_list.png` | the grid (foreign `miniclient://` cold link refused) |
| `reverify/warm_probe_mini/rv_06_mini_warm_probe.png`, `rv_07_…from_list.png` | "Character details 6" in both: the links after it were dropped (R1) |
| `reverify/warm_probe_sandbox/rv_04_sandbox_warm_probe.png` | the grid; the live own-scheme link was dropped (R1) |

### Issues at 61535d2
1. **R1 (blocker)**, `mc_feature_flow` / flow_builder 0.1.0 `flow_builder.dart:104,350,357-365`: live deep links are dropped app-wide after the first `FeatureFlow` mounts. It regresses T-0021-AC3 in the running app, and the sandbox's live links never work. Repro is above.
2. **R2 (minor)**, `app/wiring/universe_wiring/lib/src/navigators/characters_list_navigator_impl.dart:9-13`: the lazy-singleton navigator keeps the router it was built with, so `RouterRef.detach` doesn't reach it.
3. **R3 (minor)**, `app/sandbox/universe_sandbox/lib/main.dart`: there is no e2e file-drop start link (mini_client's `main()` has one), so on-sim sandbox cold links can only be driven through `defaultRouteName`.
4. Carried over from the first pass, not in scope: D5 (no back button on the list pushed from home) and the card's reserved subtitle area (DS).

---

## Re-verification at 6a3692b

- **Commit verified:** `fleet/T-0033-universe-wiring` @ `6a3692b` (detached, own worktree). It contains abbbb27, fix round 2 (ad8b82e: R2, R3), and the merge of `origin/main` df117bd, which brings in T-0035's vendored flow_builder.
- **Bazel:** `/tmp/mc-ob-T-0033-verifier`, shut down at the end.
- **Simulators:** each was created and deleted by `tool/e2e_ios.sh`:
  - `mc-T-0033-verifier-<pid>`: the R1 repro with `openurl`, the full mini_client run (`-23379`), the full sandbox run (`-25721`), the R3 mutation (`-29147`) and the R1 negative (`-30013`).
  - None was left over at either resume, and `xcrun simctl list devices | grep -c mc-T-0033` → `0` at the end.
- **Verdict:** **PASS**. Every T-0033 AC passes, R1 to R3 are fixed and each fix has a test that fails without it, and every gate is green. There is one remaining gap, G1 (below), which is tooling and not a blocker.

### 1. R1 in the running app: FIXED
- **Repro with hard assertions, on the sim.** `verifier_r1_repro_test` ([source](verifier/reverify3/r1_probe_mini/verifier_r1_repro_test.dart.txt), [log](verifier/reverify3/r1_probe_mini/e2e-verifier_r1_repro_test.log)).
  - Steps: home → Characters (the flow on screen) → `miniclient://app/placeholder/43` → `miniclient://app/characters/8`.
  - Each link goes through **`dart:ui` `channelBuffers.push('flutter/navigation', …)`**, the path `PlatformDispatcher.onPlatformMessage` takes for an engine message. The payload is `{location}` only, as iOS sends it.
  - Result: `placeholder/43 shown: location=miniclient://app/placeholder/43`, then `characters/8 shown: location=miniclient://app/characters/8`, so both routes show ([placeholder 43](verifier/reverify3/r1_probe_mini/r3_01_placeholder_43_after_flow.png), [character 8](verifier/reverify3/r1_probe_mini/r3_02_character_8_after_flow.png)).
- **My earlier probes, unchanged.** These are what found R1.
  - mini_client `verifier_warm_link_test`: from the list, `placeholder/43` gives `text=1` and `characters/8` gives `text=1`. Before, both were `0`.
  - Sandbox `verifier_warm_own_link_test`: `miniclientuniverse://app/characters/6` gives `details=1`, and the plain path `/characters/7` gives `text7=1` ([screenshot](verifier/reverify3/sandbox/rv_04_sandbox_warm_probe.png)).
  - Sandbox `verifier_foreign_link_test` now passes end to end. With live links working, its refusals carry weight: `miniclient://app/…`, `https://example.com/…` and `miniclientuniverse://other/…` show no details, and the own scheme then opens details 6.
- **The engineer's e2e tests:** `characters_link_after_flow_test` (mini_client) and `characters_sandbox_link_after_flow_test` both PASS ([06_link_after_flow](verifier/reverify3/mini_client/06_link_after_flow.png): "Placeholder detail 42" over the list; [03_sandbox_link_after_flow](verifier/reverify3/sandbox/03_sandbox_link_after_flow.png): "Character details 100486").
- **Is `pushLink` faithful?** `mc_e2e_utils.pushLink` uses `defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', pushRouteInformation{location, state: null})`.
  - **It is faithful for the Dart side, which is where R1 lived.** It calls whichever handler is currently registered on `flutter/navigation`, and flow_builder had replaced that handler. My `channelBuffers` probe, without `state` and through the engine-facing buffer, behaves the same.
  - It does **not** exercise the native leg: Info.plist's URL scheme and `FlutterDeepLinkingEnabled`, the scene delegate's `openURL`, and the engine encoding the call.
- **Real delivery path: none.**
  - While the app was running, the probe signalled readiness and the runner ([script](verifier/reverify3/r1_probe_mini/run_openurl_probe.sh.txt), [log](verifier/reverify3/logs/run_openurl_probe.log)) ran `xcrun simctl openurl <udid> miniclient://app/placeholder/44`, which returned exit 0.
  - The app never received the link (`reached the app: false`). [`r3_03_simctl_after_openurl.png`](verifier/reverify3/r1_probe_mini/r3_03_simctl_after_openurl.png) shows SpringBoard's **"Open in “Mini Client”?" Cancel / Open** alert over "Character details 8", exactly F-0020.
  - The file-drop hook only covers cold start, so the native leg of a live link stays unverified on the simulator. This is **G1** (P-042).
- **On-device negative.** Stock `flow_builder-0.1.0/lib/flow_builder.dart` swapped into the scratch copy only: `characters_link_after_flow_test` **FAILs** ("Timed out … waiting for the linked placeholder", exit 1; [log](verifier/reverify3/logs/r1-neg.out)).

### 2. `links_after_flow_test` (un-skipped): PASS, and it fails without the fix
- `test --nocache_test_results //app/mini_client:links_after_flow_test` → PASS ([log](verifier/reverify3/logs/r3-laf.log)). There is no `skip:` left. The comment at `app/mini_client/BUILD.bazel:130` still says "skipped until T-0035" (N1).
- **Revert only the T-0035 hunk** (`case 'pushRouteInformation': return _pushRouteInformation(…)`) → **FAIL** ([log](verifier/reverify3/logs/r3-laf-revert-hunk.log)).
- **The whole stock upstream file** → **FAIL** ([log](verifier/reverify3/logs/r3-laf-upstream.log)).
- The vendored file was restored, and `git status` is clean.
- The vendored lib differs from pub.dev's 0.1.0 by exactly `0001-forward-pushRouteInformation.patch`: the new case, `default → false`, the intercepted pop answering `true`, and `_pushRouteInformation`.

### 3. R2: FIXED
My earlier probe, rerun ([log](verifier/reverify3/logs/r3-probe-detach.log)):
- attach r1, resolve the navigator, then detach and dispose r1, then attach r2.
- Result: the same navigator instance, `second.location=/characters/9`, "Character details 9" shown, and pop returns to `/characters`.
- After a final detach, `openCharacter` throws the clear `StateError`.

The navigator now holds `RouterRef` and reads `.router` per call (`characters_list_navigator_impl.dart`). The engineer's test "pushes to the live router after the router was replaced" passes, and the mutation that restores first-router caching is killed.

### 4. R3: FIXED
- `characters_sandbox_link_test` (file drop `miniclientuniverse://app/characters/<id>`) PASS on the sim ([02_sandbox_start_link](verifier/reverify3/sandbox/02_sandbox_start_link.png): back arrow, "Character details 100486").
- **On-device mutation:** with `links.offer(link)` commented out in the scratch copy's sandbox `main.dart`, the test **FAILs** (timed out, exit 1; [log](verifier/reverify3/logs/r3-mut.out)).

### 5. Merge review: clean
- **`MODULE.bazel.lock` vs main df117bd**, structural JSON diff ([log](verifier/reverify3/logs/module-lock-vs-main.txt)):
  - Only **added** repos: `pub_deps__{integration_test,flutter_driver,platform,process,sync_http,webdriver}` and their android and facts entries.
  - **76** `packages` / `lock_packages` lists gain exactly those 6 names and lose none.
  - One `recordedInputs` entry changes: the `pubspec.lock` hash.
  - No version or sha256 of an existing repo changed.
- **`pubspec.lock` vs main:** it adds only `flutter_driver`, `fuchsia_remote_debug_protocol`, `integration_test` (SDK), `platform 3.2.0`, `process 5.0.6`, `sync_http 0.3.1` and `webdriver 3.2.0`.
- **`fvm flutter pub get --enforce-lockfile`:** exit 0, "Got dependencies!", and the tree stays clean ([log](verifier/reverify3/logs/r3-pubget.log)).

### 6. Gates, mutations and the full e2e
- **`T-0033-AC5_gates.sh`:** **PASS**, all 8 gates (uncached T-0033 tests, then `test //...` at **84/84**; lint; `mc_arch_check`; `rules_fork.sh check`; format; `l10n_check`; fixtures closure; both `--config=sim` app builds) ([report](verifier/reverify3/T-0033-AC5_gates.md)).
  - `universe_wiring` now depends on `app_core` in production (for `RouterRef`). That fits plan 01 §4.2, where wirings reach other groups through `app_core`, and the arch check passes.
- **`documents/evidence/T-0033/engineer/mutations.sh`:** **9/9 killed** ([log](verifier/reverify3/logs/mutations.log)). Its "push becomes go" mutation (`_routerRef.router.go(` inside `unawaited`) does not compile, because `go` returns `void`, so it is killed by a build failure rather than a test (N2).
- **My own mutations** (private script, [logs](verifier/reverify3/logs/)): push→go at test level (`unawaited(Future.sync(() => …go(…)))`), the wrong id, and `AppLocations.character` → `/character/$id` were all **killed** by `routes_test` test failures.
- **Full e2e via `tool/e2e_ios.sh`, all targets:**
  - **mini_client 4/4 PASS:** journey 24 s, deep link 30 s, link-after-flow 19 s, and my warm probe 33 s ([summary](verifier/reverify3/mini_client/e2e-summary.md)).
  - **sandbox 6/6 PASS:** sandbox 23 s, start link 18 s, link-after-flow 31 s, and my cold, foreign and warm probes ([summary](verifier/reverify3/sandbox/e2e-summary.md)).

### Screenshots (all ≤ 1200 px, viewed)
| File | What is visible |
|---|---|
| `reverify3/mini_client/01_home.png` | home, `Config: env=e2e`, Characters / Open placeholder 7 |
| `reverify3/mini_client/02_characters_list.png` | the grid **now with a back arrow** (T-0034 fixed D5), and shorter cards (the subtitle reserve is gone) |
| `reverify3/mini_client/03_preview.png` | "Amber Alchemist" preview, "See full profile" |
| `reverify3/mini_client/04_full_profile_placeholder.png` | "Character details 100486" |
| `reverify3/mini_client/05_deep_link_characters.png` | the grid as the start screen, no back arrow (cold link) |
| `reverify3/mini_client/06_link_after_flow.png` | "Placeholder 42 / Deep link: miniclient://app/placeholder/42", reached from the list |
| `reverify3/sandbox/01_sandbox_characters.png` | the sandbox grid with art |
| `reverify3/sandbox/02_sandbox_start_link.png` | "Character details 100486" (file-drop start link) |
| `reverify3/sandbox/03_sandbox_link_after_flow.png` | "Character details 100486" (live link over the list) |
| `reverify3/sandbox/rv_04_sandbox_warm_probe.png` | "Character details 7" (plain-path live link) |
| `reverify3/r1_probe_mini/r3_01…`, `r3_02…` | "Placeholder detail 43", then "Character details 8" |
| `reverify3/r1_probe_mini/r3_03_simctl_after_openurl.png` | the SpringBoard "Open in “Mini Client”?" alert (G1) |

### Issues at 6a3692b
1. **G1 (minor, tooling; P-042)**: the harness has no real path for a link to a running app. `simctl openurl` stops at SpringBoard's prompt (screenshot above), so the native leg of live deep links isn't verified on the simulator. The Dart side is covered by `pushRouteInformation` on `flutter/navigation`, through both the registered handler and `channelBuffers`. No new tooling was built, as instructed.
2. **N1 (nit)**: `app/mini_client/BUILD.bazel:130` still reads "R1 regression (skipped until T-0035)". The test is no longer skipped.
3. **N2 (nit)**: in `documents/evidence/T-0033/engineer/mutations.sh`, "push becomes go" is killed by a compile error, not a test. The script also writes a fixed `/tmp/mc-mut.log`, so two runs at once would collide. The test-level variant is killed (above).

### Process note: shared scratchpad
- The session scratchpad is shared between fleet agents. My first-round helper `scratchpad/mut.sh` had been overwritten by the T-0035 Verifier's script, which targets `.claude/worktrees/agent-a2fe366999ee7848d`.
- When I invoked it once by name (21:33), its argument handling failed before any test ran. Its "restore" step then copied `scratchpad/flow_builder.patched.dart` onto that worktree's `third_party/flow_builder/lib/flow_builder.dart`.
- A read-only `cmp` afterwards shows that file is **byte-identical to the committed vendored file**, so its content is what its HEAD holds. I made no other change there.
- After that I used only `scratchpad/verifier-T0033-r3/`. The fleet should give each agent its own scratch subdirectory.
