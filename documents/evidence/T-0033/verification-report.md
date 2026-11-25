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
