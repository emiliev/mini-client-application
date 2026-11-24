# Verification report — T-0021: App shell (`app_core` + `app/mini_client`) on the iOS simulator

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0021-app-shell` @ **`f7a4fe8`** (round 2: the review fixes on top of `19b028a`), checked out as `fleet/T-0021-verify2`. Round 1 at `19b028a` (PASS) follows below, unchanged.
- **Simulators:**
  - round 2: `mc-T-0021-verifier`, iPhone 17 Pro, iOS 26.2 (UDID E6734F8F-…);
  - round 1: the same name (UDID 728FFDC9-…), plus `mc-T-0021-verifier-18`, iPhone SE (3rd generation), iOS 18.2 (UDID 8B14027D-…).
  - I created and deleted all of them myself, and none exists any more. The shared simulators were not touched.
- **Bazel output bases:** `/tmp/mc-ob-T-0021-verifier`, and `/tmp/mc-ob-T-0021-verifier-cold` (round 1 only) for the cold `build //...` with an execution log. Both servers are shut down.
- **Verdict:** **PASS** at `f7a4fe8`. Every AC passes, with AC3 judged as amended by the TL (F-0020).

## Round 2: the review fixes at `f7a4fe8`

### Gates (at `f7a4fe8`)
| Gate | Command | Result |
|---|---|---|
| L1–L3 Tests | `tool/bazelw test --nocache_test_results //...` | **39 / 39 pass** |
| L0 Lint | `tool/bazelw build --config=lint //...` | pass |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Sim app build | `tool/bazelw build --config=sim //app/mini_client:mini_client_ios` | pass. The `.ipa` kernel contains `DIInitializationAbandoned`, so it is the new build. |

- **Per-test check:** a `--test_output=all` run of `mc_di:di_container_test`, `boot_test`, `links_and_hooks_test` and `app_test` lists every test as PASS, including all the new ones.
- **`mc_di`:** 17 tests pass. The diff only *adds* the 2 abandon tests; the existing 15 are unchanged.
- Logs: [`verifier/gates-f7a4fe8.log`](verifier/gates-f7a4fe8.log).
- **Simulator:** I installed the new build on a fresh `mc-T-0021-verifier` (iOS 26.2).
  - [`verifier/r2-ac6-home.png`](verifier/r2-ac6-home.png) shows home in Inter with **Config: env=dev**.
  - [`verifier/r2-ac3-e2e-link.png`](verifier/r2-ac3-e2e-link.png) shows the file-drop link `placeholder/2207` opening *Placeholder detail 2207*, and the file was consumed.
  - The simulator is deleted.

### The fixes, judged
| # | Fix | Test(s) | Judgement | Mutation → result |
|---|---|---|---|---|
| 1 | **Link in the gap** between `BootReady` and the router mounting | `app_test` "T-0021-AC4 a link delivered between BootReady and the router's first frame is held and forwarded …" | **Sound.** `PendingLinks` was registered before `runApp`, so it sees links before go_router's observer. It stays attached until a post-frame callback after `setState`, which is when `MaterialApp.router` has built. Then it `drain()`s, detaches, and `router.go(late)`. The test pushes `placeholder/99` inside the router factory, i.e. ready but not yet mounted. It asserts `received == 1`, detached, *Placeholder detail 99*, and no exception. | (a) detach immediately in `_onBoot`, as before the fix: **FAIL** (`received` expected 1, actual 0). (b) still held but `router.go(late)` removed: **FAIL** (*Placeholder detail 99* not found). |
| 2 | **Failure after the timeout** → `BootFailed`, recorded to monitoring | `boot_test` "T-0021-AC1 a boot that fails after the timeout showed …" | **Yes.** At 11 s the timed-out key shows. Then `completeError('late failure')` gives the failed key, the error text, and exactly 1 `ErrorEntry` containing *late failure* in the injected sink. `_isLive` accepts `BootTimedOut`. | `_isLive` limited to `BootBooting`: **FAIL**, together with fix 4's test. |
| 3 | **A hung boot can be retried** (P-028) via `abandonDIContainerInitialization()` | `mc_di` "T-0021-AC2 a fresh call succeeds after abandon …" and "… abandon with nothing running does nothing"; `boot_test` "T-0021-AC2 Retry escapes a never-completing root initializer …" and "T-0021-AC2 … Retry abandons the attempt and starts a fresh one" | **Safe.** See the analysis below. The mc_di test asserts: still one call at a time before abandon; a fresh call publishes `fresh`; when the hung one returns it throws `DIInitializationAbandoned`, the root is still `fresh`, and its `Foo` was disposed (`disposed == 1`). The widget test uses the **real** `initializeDIContainer` and root list with an initializer that never completes. Retry gives `runs == 2`, home, and `AppConfig` registered. The bloc test checks that the abandoned attempt's late error is ignored. | (a) the generation check removed, so the abandoned run carries on and **publishes**: the mc_di test **FAILS** (`Expected: throws DIInitializationAbandoned`). (b) `abandon` doesn't release `_initializing`: the mc_di test and the P-028 widget test **FAIL**. |
| 4 | **Success after the timeout** → ready | `boot_test` "T-0021-AC2 a boot that succeeds after the timeout showed goes to ready" | **Yes.** At 11 s the timed-out key shows; `held.complete()` gives the router's `home`. | the same `_isLive` mutant: **FAIL** |
| 5a | **The host `app` is enforced**, in `normalise` and in the router `redirect` | `links_and_hooks_test` "T-0021-AC4 normalise sends links for another host or scheme to /" (`miniclient://evil`, `https://app`, `otherapp://app`); `app_test` "T-0021-AC3 a link for another host or scheme shows home …" | **Yes.** The widget test pushes `miniclient://evil/placeholder/5` to the running router and asserts home, not the detail page. | the `redirect` host check disabled: **FAIL** (*Placeholder detail 5* found). So go_router alone would route a foreign host, and the redirect check is load-bearing. |
| 5b | **An unknown scenario fails boot** | `boot_test` "T-0021-AC1 an unknown backend.scenario fails boot with a clear error" | **Yes.** `"hapy"` throws a `StateError` naming `"hapy"` and the known names, including `happy`, and nothing is published. | (not mutated: a direct assertion on the message) |
| 5c | **`readE2eStartLink` is safe on errors** | `links_and_hooks_test` "T-0021-AC3 an unreadable e2e start link file is ignored" (`chmod 000`) | **Yes.** It catches `FileSystemException` (read or delete) and `FormatException` (bad UTF-8) and returns null, so a test hook can't stop the app starting. It is still compiled out of release builds; round 1 verified that, and the guard in `main()` is unchanged. | — |
| 5d | **The warm `openurl` check uses id 43** | `tool/checks/T-0021-AC3_AC6_sim.sh` | **Yes** for the command, line 109, `placeholder/43`. Nit: the report line 124 still prints "warm (placeholder/42)". | — |

All mutants were reverted; `git status` showed only my evidence files afterwards.

### Safety of `abandonDIContainerInitialization()`
- **An abandoned run never publishes.**
  - Each call takes `generation = ++_generation`, and `abandon` bumps `_generation`.
  - After every `await initializer.init(staged)` the run checks its generation and throws `DIInitializationAbandoned` if it is stale.
  - Nothing is awaited between the last check and `_root = staged`, so `abandon` cannot interleave there.
  - A stale run that throws its own error instead also ends in `catch`.
- **It disposes its staging.** The thrown error goes through the existing `catch`, which runs `staged.reset()`, and that disposes what the run registered (the test checks `disposed == 1`).
- **No double registration.**
  - The fresh run builds into its own new `GetIt.asNewInstance()`.
  - In production, `appRootInitializers()` is called per attempt, so even the forwarding `MockBackendHttpAdapter` is per attempt.
  - The stale run stops at its next initializer boundary, so it registers nothing further.
- **The in-flight guard is handled correctly.**
  - `abandon` clears `_initializing` at once.
  - The stale run's `finally` only clears it if its generation is still current, so it can't clear the flag of the fresh run.
  - `abandon` with nothing running does nothing.
- **Limits:**
  - The hung initializer itself can't be cancelled, only discarded (documented).
  - Side effects it causes *outside* its staging container (files, sockets) are not undone.
  - Acceptable for boot. TL-approved API.
- **Theoretical race (negligible):** `initializeDIContainer` publishes, then the user taps Retry before `_BootSucceeded` is handled. Retry would start a run that throws "already initialised". This can't happen in practice: completion callbacks and the bloc's `add` run as microtasks, which drain before any tap event.

### Round 2 test-integrity audit
- **No test was deleted or skipped.** Two round-1 AC2 tests were **rewritten to match the changed behaviour**, which the review asked for:
  - "Retry waits for the same run" (`taskRuns == 1`) became "Retry abandons and starts a fresh one", which asserts `abandons == 1`, 2 attempts, and that the stale result is ignored.
  - "A late result alone does not leave the timeout screen" became "succeeds after the timeout → ready".
  - Neither is a weakening: each new assertion is stricter about the new contract, and the mutants above show it.
- No `// ignore:` and no golden files changed.

### Round 2 issues (none block)
1. **(doc)** In the task file's Outcome, the `BootBloc` bullet still ends with the round-2 sentence "Retry after a timeout waits for the still-running run instead of starting a second one … a run that finished late is picked up by Retry". It contradicts the new behaviour stated earlier in the same bullet.
2. **(nit)** `tool/checks/T-0021-AC3_AC6_sim.sh` line 124 still reports "warm (placeholder/42)", though the command now uses 43.
3. The round 1 low items still stand: the profile-build hook, and `main.dart` outside the lint check.

---

# Round 1 (at `19b028a`, PASS)

## Gates re-run independently (at `19b028a`)
| Gate | Command | Result |
|---|---|---|
| L1–L3 Tests | `tool/bazelw test --nocache_test_results //...` | **39 / 39 pass** |
| L0 Lint (format + analyze aspects) | `tool/bazelw build --config=lint //...` | pass (90 targets) |
| Architecture | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Sim app build | `tool/bazelw build --config=sim //app/mini_client:mini_client_ios` | pass, `mini_client_ios.ipa` |
| R14, no AOT in `//...` | `tool/bazelw build --config=cold --execution_log_compact_file=… //...` (fresh output base, disk cache off, so 647 spawns really ran) | pass. The execution log has **0** `FlutterAotMacho` entries, against 320 `DartKernel` and 18 `FlutterAssetBundle` entries as a control. The `aquery --output=summary` of `deps(//... except manual)` has no AOT mnemonic either. `aquery mnemonic("FlutterAotMacho", …)` matched no actions. |
| Release build (my extra check) | `tool/bazelw build --config=device //app/mini_client:__mini_client_ios_app_framework` | pass. This gives an arm64 AOT `App.framework/App`, used for the hook review below. |

Logs: [`verifier/gates.log`](verifier/gates.log).

**Bundle checks on the sim `.ipa`:**
- `FontManifest.json` has `packages/mc_ds_theme/Inter` with Regular, 500, 600 and 700, and all 4 `.ttf` files are bundled.
- `assets/app_config.json` is the `dev` config.
- Info.plist has `CFBundleURLSchemes = [miniclient]`, `FlutterDeepLinkingEnabled = true` and bundle id `com.emiliev.miniclient`.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0021-AC1 | a failing root initializer shows an error, and Retry succeeds on attempt 2 | `//app/wiring/app_core:boot_test`: "T-0021-AC1 a failing root initializer …" and "T-0021-AC1 BootBloc (a McBloc) discards a failed run …" | **Yes.** The widget test uses the real root list plus a wiring that throws once. It asserts the failed key, *Could not start*, the error text, and that `AppConfig` is not registered. After the Retry tap it asserts `runs == 2`, the router's `home`, no `BootPage`, and that `AppConfig` is registered. The bloc test also asserts 1 `ErrorEntry` in monitoring (`McFailureState`). **Extra mutant:** a failed run that isn't discarded (`_run = null` removed) **fails** both AC1 tests and AC5. | PASS |
| T-0021-AC2 | boot > 10 s shows the timeout state with Retry (fake clock) | `boot_test`: "T-0021-AC2 boot taking longer than 10 s …" and "T-0021-AC2 a boot that finishes while the timeout shows …" | **Yes.** `testWidgets`' fake clock shows loading at 9 s, then at 11 s the timed-out key, *Taking too long*, *…within 10 s.* and Retry. Retry waits for the same run (`taskRuns == 1`), so nothing is registered twice. **Mutant** (the timeout `Timer` removed): **both AC2 tests fail** (`boot.timedOut` found 0 widgets). | PASS |
| T-0021-AC3 (amended) | (a) a URI on the platform channel go_router listens on shows its route; (b) a simulator screenshot of the linked route via the file drop | (a) `//app/mini_client:app_test` "T-0021-AC3 a miniclient://app/placeholder link delivered on the platform navigation channel …". (b) my screenshots `verifier/ac3-e2e-link.png` (26.2) and `verifier/ios18-2-e2e-link.png` (18.2) | **Yes.** (a) sends `pushRouteInformation` with `location: miniclient://app/placeholder/42` on `flutter/navigation` (the message the iOS embedder sends) to the running app, then asserts *Placeholder detail 42*, a `placeholder` build, and that back pops to home. **Extra mutant** (`PendingLinks` never detaches): AC3 and both AC4 tests **fail**. (b) I chose my own IDs (1234 and 1802, not the Engineer's 42) so the screenshots can't be stale. In both, the app consumed the file (it is gone from `tmp/`) and shows *Placeholder detail N* with a back button. | PASS |
| T-0021-AC4 | a cold-start link during held boot shows its route once boot succeeds; no builder or `redirect` before `ready` (counted) | `app_test`: "T-0021-AC4 a cold-start link held during boot …" and "T-0021-AC4 a link pushed while boot is held wins …" | **Yes.** `defaultRouteName` is `miniclient://app/placeholder/7` and boot is held by a `Completer`. While held: no `Router`, `probe.builds` and `probe.redirects` empty, link pending. After completion: *Placeholder detail 7*, `beforeReady == 0`, a redirect ran, links detached. The second test covers a link pushed during boot, and links after ready going to go_router. **Mutant** (the router created at start and mounted `Offstage` under the boot page): the first AC4 test **fails** on `probe.builds` (`Expected: empty, Actual: ['home', 'placeholder']`), and so does the second. | PASS |
| T-0021-AC5 | same link plus a failing first boot: Retry replays the link once, and every root type is registered exactly once | `app_test`: "T-0021-AC5 …" | **Yes.** Every root initializer is wrapped to record its container, and the failing initializer comes last, so attempt 1 registered everything. It asserts one router created, `links.takes == 1`, one `placeholder` build, and `beforeReady == 0`. Each initializer ran exactly twice, into two non-identical containers, and the discarded one is empty. The published root holds attempt 2's `AppConfig`, `Monitoring`, `FileStore`, `MockBackend`, `Dio` and `EventBus`. Within one container GetIt refuses a duplicate. **Mutant** (in `mc_di`, the first attempt's staging container is reused on Retry, with `allowReassignment = true` so GetIt can't throw): the AC5 test **fails** (`Expected: false, Actual: <true>` on the identical-container check). | PASS |
| T-0021-AC6 | the sim build succeeds and the app launches on a private sim showing home in Inter; the gates pass; no `FlutterAotMacho` in `build //...` | gates above; my screenshots `verifier/ac6-home.png` (26.2) and `verifier/ios18-2-home.png` (18.2) | **Yes.** The build, the 4 gates and R14 pass (the table above). On both runtimes the app shows *Marvel universe*, the Inter sample lines with 700, 600 and 500 weights, **Config: env=dev**, and the red DS button. Inter is visibly not SF: compare the app text with the SF system alert in `f0020-openurl-warm.png`. The FontManifest confirms it. | PASS |

## Mutation summary (all reverted; `git status` clean afterwards)
| # | Mutation | Expected to catch | Result |
|---|---|---|---|
| 1 | `mc_di` reuses the attempt 1 staging container on Retry (no reset, `allowReassignment = true`) | AC5 | AC5 **FAIL** |
| 2 | `McApp` builds the router at start and mounts it `Offstage` during boot | AC4 | both AC4 **FAIL** (`builds = ['home','placeholder']` before ready) |
| 3 | `BootBloc._begin` starts no timeout `Timer` | AC2 | both AC2 **FAIL** |
| 4 (extra) | `BootBloc` keeps the failed run (`_run = null` removed) | AC1 | both AC1 and AC5 **FAIL** |
| 5 (extra) | `McApp` never detaches `PendingLinks` | AC3 | AC3 and both AC4 **FAIL** |

## Simulator check (F-0020)
- On iOS 26.2 I ran `xcrun simctl openurl <my udid> miniclient://app/placeholder/55` with the app frontmost. It exits 0, and SpringBoard shows **Open in “Mini Client”?** with Cancel and Open over the dimmed app (`verifier/f0020-openurl-warm.png`). The route does not change.
- iOS 18.2 shows the same prompt in the older alert style (`verifier/ios18-2-openurl-warm.png`).
- F-0020 is confirmed, and the AC3 amendment is justified. The real `openurl` e2e stays P-042.

## Review of the `main()` file-drop hook
`main()` reads `<data container>/tmp/mc_e2e_link` only under `if (!kReleaseMode)`. It reads the file once, deletes it, and hands the link to `PendingLinks.offer()`.
- **Release builds compile it out.** `kReleaseMode` is a `const` (`dart.vm.product`), so the AOT tree shaker drops the branch and `readE2eStartLink`. I checked the release AOT binary: `strings` finds **0** hits for `mc_e2e_link`, `readE2eStartLink` and `e2eStartLinkFile`. As a control, the same binary does contain `PendingLinks`, `Placeholder detail` and `Config: env=`, and the debug `kernel_blob.bin` contains `mc_e2e_link`.
- **The surface is small even where it is active.** The file sits in the app's own sandbox `tmp/`, so only the app, the simulator host or a debugger can write it. Its content goes through the same normaliser and the same `GoRouter` (with the future guard `redirect`) as any `miniclient://` link, which any app or web page can already send. It is consumed once.
- **Verdict: acceptable.** One nit: it is also active in **profile** builds (`kReleaseMode` is false there). Profile builds aren't distributed (Q-007), so this is harmless. If the TL wants it tighter, `kDebugMode` would exclude profile, but that would stop perf journeys from using the file.

## Conformance
- **Glue (Tide §2.1):** `app/mini_client` holds only `main`, the root widget, typed placeholder routes and composition of the 7 wirings. `app_core` holds the boot, DI list, links and shell. There is no business logic.
- **DI order:** config → monitoring → storage → mocked backend → `ApiClientDIInitializer` → event bus → 7 wirings. That is utilities first, then wirings; features initialise in their flows. Plan 01 §3.4's sketch puts the mocked backend *after* the API client, setting `Dio.httpClientAdapter` there. The implementation puts it *before* and gives `ApiClientDIInitializer(adapter: MockBackendHttpAdapter)`, a forwarding adapter that `MockedBackendDIInitializer` points at the `MockBackend` built from `AppConfig`. This fits T-0023's adapter-injection API and is equivalent.
- **Mocked backend under Dio (T-0023):** a test asserts `dio.httpClientAdapter` is the forwarder, that its target is `diContainer<MockBackend>().adapter`, and that a real request reaches the backend (404 plus `recentTraffic` of 1).
- **No dart-defines (R13):** there is no `fromEnvironment` or `dart-define` in `app/`. The config comes from the bundled `assets/app_config.json` (a genrule copy of `//tool/bazel/config:app_config`), and the screenshot shows `env=dev`.
- **Inter bundled (P-031):** `flutter_font_family(":inter")` on `mc_ds_theme`, confirmed in the FontManifest and on screen.
- **`BootBloc` is a `McBloc`:** `final class BootBloc extends McBloc<BootEvent, BootState>`, and `BootFailed implements McFailureState`.
- **R29 lifecycle:** `PendingLinks` is installed before `runApp`, `MaterialApp(home: BootPage)` shows until ready, then one `GoRouter` with the held link, then detach. This matches plan 01 §3.4 steps 1–4.
- **R14:** both app targets are `manual`, and `build //...` runs no AOT.

## Hygiene
- **Changes outside `app/`, `documents/` and the task's check script:** only `pubspec.yaml` (9 `workspace:` members) and `utility/mc_ds_theme/BUILD.bazel` (the Inter font family). This matches the handoff. `pubspec.lock` is unchanged.
- **No generated files committed:** no `*.g.dart`, lock changes, `.dart_tool`, build outputs or Xcode projects. The 18 AppIcon PNGs are the standard Runner template.
- **Screenshots:** all 8 Engineer screenshots are 1200 px tall, and so are my 6.

## Test-integrity audit
- No tests were deleted, skipped or weakened. The branch only adds tests (`boot_test`, `links_and_hooks_test`, `app_test`).
- No lint suppressions were added; there is no `// ignore:` in `app/`.
- No golden files changed.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| AC6 home, 26.2 | `verifier/ac6-home.png` | *Mini Client* app bar, *Marvel universe*, Inter sample text and weights, **Config: env=dev**, *Open placeholder 7*, DEBUG banner | yes |
| AC3 (b) link, 26.2 | `verifier/ac3-e2e-link.png` | *Placeholder 1234* app bar with back, *Placeholder detail 1234*, *Deep link: miniclient://app/placeholder/1234* | yes |
| F-0020, 26.2 | `verifier/f0020-openurl-warm.png` | the *Open in “Mini Client”?* alert (Cancel / Open) over the dimmed app | confirms F-0020 |
| AC6 home, 18.2 | `verifier/ios18-2-home.png` | same home content on iPhone SE | yes |
| AC3 (b) link, 18.2 | `verifier/ios18-2-e2e-link.png` | *Placeholder detail 1802* with back | yes |
| F-0020, 18.2 | `verifier/ios18-2-openurl-warm.png` | the same alert, iOS 18 style | confirms F-0020 |

## Issues found (none block the merge)
1. **(low)** The file-drop hook is active in profile builds as well as debug. See the hook review above.
2. **(low)** `lib/main.dart` is not covered by the lint aspect. It is excluded from `:mini_client_lib`, and the app target is `manual`, so `build --config=lint //...` never analyses it. Building the app target with `--config=lint` doesn't analyse it either. `spike/hello` follows the same pattern. Candidate pending work: analyse app `main.dart` files.
3. **(info)** `NotFoundPage` lives in `app/mini_client`, while plan 01 §4.2 says "app_core's not-found page". The DI order also differs from the §3.4 sketch, as described under Conformance. The plan text could be updated to match.
4. **(info)** The scope mentions "an e2e smoke journey through `tool/e2e_ios.sh`". It was delivered as `tool/checks/T-0021-AC3_AC6_sim.sh` instead. No AC depends on it.

## Notes for the Tech Lead
- Every mapped test failed against its targeted mutant, so the AC tests aren't tautological.
- R14 is confirmed with a real cold execution log, not only `aquery`.
- The server and simulators are cleaned up: both of my simulators are deleted, and both of my Bazel servers (`/tmp/mc-ob-T-0021-verifier` and `-cold`) are shut down.
