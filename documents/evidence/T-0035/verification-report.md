# Verification report — T-0035: Deep links survive a mounted `FeatureFlow`

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-25
- **Branch / commit verified:** `fleet/T-0035-flow-deep-links` @ `43e97a4`, detached in the Verifier's own worktree
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0035-verifier …`, shut down at the end
- **Simulator:** none. The task is kit-level, with no UI and no e2e AC. App-level evidence is the T-0033 R1 repro under Bazel (`flutter_test`), below.
- **Verdict:** **PASS**. Every AC passes. There is one major defect outside the ACs (D1: the provenance check goes permanently red once this merges) and two minor ones. See "Issues found".

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| pub | `fvm flutter pub get --offline --enforce-lockfile` | rc 0; tree clean afterwards |
| Tests, touched packages uncached | `test --nocache_test_results --test_output=all //utility/mc_feature_flow/... //feature/characters/characters_list/...` | **8/8 targets** ([log](verifier/logs/v-test-uncached.log)): channel 6/6, `feature_flow_test` 10/10, `flow_kit_test` 16/16, plus all 5 `characters_list` targets |
| All gates | `MC_BAZEL_STARTUP=--output_base=/tmp/mc-ob-T-0035-verifier tool/checks/T-0035-AC4_gates.sh --role verifier` | **PASS** ([report](verifier/ac4-gates.md), [log](verifier/logs/ac4-gates.log)): `test //...` 78/78, `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, coverage |
| Coverage, own parser | [`scripts/mylcov.py.txt`](verifier/scripts/mylcov.py.txt): union of the `coverage.dat` files by `package:` URI | `mc_feature_flow` **142/143 = 99.3 %** (missed `feature_flow.dart:213`, which this diff doesn't touch). `characters_list` hand-written **156/156** ([numbers](verifier/logs/coverage-own-parser.txt)). The vendored `flow_builder` isn't instrumented (no LCOV records) |
| Provenance | `tool/checks/T-0035-AC4_provenance.sh --role verifier` | **PASS** ([report](verifier/ac4-provenance.md)) |
| Hosted target gone | `query @pub_deps//:flow_builder` | `no such target … 'flow_builder' not declared` |
| Lint-exempt targets | `query 'attr(tags, "no-dart-(analyze\|format)", //...)'` | `//third_party/flow_builder:flow_builder` is new. The other 4 (`_stage` codegen targets) are pre-existing |
| Vendored analyze, informational | `fvm dart analyze third_party/flow_builder` | 2 infos, both upstream (`onPopPage`, `onPopInvoked` deprecated). **The patch adds no new issue**, including none for the `@protected` / `@visibleForTesting` `handlePushRoute` |
| Final re-check at HEAD after the scratch merge was reset | `test --nocache_test_results //utility/mc_feature_flow/...` | 3/3 ([log](verifier/logs/v-final-head-recheck.log)); `git status` showed only my evidence |

## TL position check: `WidgetsBinding.handlePushRoute` on Flutter 3.47.7
Read from `~/fvm/versions/3.47.7/packages/flutter/lib/src/widgets/binding.dart`.
- **Visibility:** `handlePushRoute` (`:1253-1277`) is a public method annotated `@protected @mustCallSuper @visibleForTesting`. It isn't deprecated; only `WidgetsBindingObserver.didPushRoute` is (`:181`).
  - Stock 0.1.0 already calls it for `pushRoute`.
  - `_SystemNavigationObserver implements WidgetsBinding`, so the analyzer reports no protected-member use.
- **Semantics:**
  - It builds `RouteInformation(uri: Uri.parse(route))` and calls `didPushRouteInformation` on the observers in order.
  - That is the same as the private `_handlePushRouteInformation` (`:1279-1302`), except that the latter also passes `state`.
  - Both return a `bool`.
- **The reply matters on iOS:**
  - `FlutterEngine.mm:1631-1656` `sendDeepLinkToFramework` reads the reply of `pushRouteInformation`, and only `@YES` counts as success.
  - `FlutterAppDelegate.mm:157-183`: on failure, a universal link is thrown back to the system.
  - The patch returns `handlePushRoute`'s `bool`, so this is correct. Stock answered `null`, which counts as "unhandled".
- **iOS sends only `location`** (`url.absoluteString`), with no `state`. So dropping `state` is harmless on iOS, as the TL accepted.
- **Receivers:**
  - `MaterialApp.router` with a custom delegate gets the full URI, including query and fragment.
  - go_router 17.5.0 gets it through `routerConfig`, with `GoRouterState.uri` keeping query and fragment.
  - Custom-scheme absolute URLs are kept: `miniclient://app/characters/6?tab=info#bio`.
  - Evidence: VPROBE1, VPROBE5 and the baseline below.
- **Verdict on the entry point:** right for 3.47.7. Residual risk: it is `@visibleForTesting`, so a future Flutter could reshape it. The provenance check plus the channel tests would catch that.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0035-AC1 | A real `FeatureFlow`, a `pushRouteInformation` message through `SystemChannels.navigation`, and the router gets the location; red on stock | `flow_navigation_channel_test`: "T-0035-AC1 a deep link reaches the router while a FeatureFlow is mounted"; "T-0035-AC1 the legacy pushRoute …" | **Yes.** `_send` calls `tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', JSONMethodCodec().encodeMethodCall(…))`. The router is never called directly, and the recording `RouterDelegate.setNewRoutePath` is the observable. **Stock swap (my own):** I copied the pub.dev archive's `lib/flow_builder.dart` over the vendored one: **4 failed, 2 passed** ([log](verifier/logs/m0-stock-0.1.0.log)). The failures were AC1 "while mounted", AC2 "after dispose", AC2 "nested" and AC2 "unknown method". The controls were AC1 "legacy pushRoute" and AC2 "popRoute pops a pushed flow page". **Gap:** the reply value and fragments aren't pinned (D2) | **PASS** |
| T-0035-AC2 | After dispose the channel behaves as with no flow (links, `popRoute`); nested flows work | "T-0035-AC2 after the flow is disposed …", "… a flow nested inside another flow …", "… popRoute pops a pushed flow page … falls through at the flow root", "… an unknown navigation method is answered like the framework does (false)" | **Yes**, with my probes as the stronger check. **VPROBE2** compares a full script (2 links, legacy `pushRoute`, handled and unhandled `popRoute` with the `SystemNavigator.pop` count, unknown method, a link with `state`) after dispose against the same script run first in the process, before any FlowBuilder mounted, through the framework's own handler. **Every reply and effect is identical**, except `state` (`st` → `null`), which is accepted | **PASS** |
| T-0035-AC3 | Existing `mc_feature_flow` and `characters_list` tests unchanged and green; back gestures and edge swipe as before | `feature_flow_test` (T-0022-AC5 ×4 edge swipes), `flow_kit_test`, 5 `characters_list` targets | **Yes.** `git diff origin/main...HEAD --stat -- '*_test.dart' '*.feature' '*.png'` lists only the new `flow_navigation_channel_test.dart`. All pass uncached. The T-0022 Verifier's **VPROBE1-4** (`documents/evidence/T-0022/verifier/probes-cd30e2e.dart.txt`), appended temporarily to `feature_flow_test` and never committed, **4/4 PASS** ([log](verifier/logs/p1-probes.log)), with real iOS drags from x=2 | **PASS** |
| T-0035-AC4 | Provenance; upstream draft; gates; locks re-resolved with flow_builder the only change | `tool/checks/T-0035-AC4_provenance.sh`, `tool/checks/T-0035-AC4_gates.sh`, `documents/upstream/U-X-flow_builder-navigation-channel/README.md` | **Yes, at this SHA.** Independently: I downloaded the archive myself (sha256 `9e66aa72…3f8d` ✓). My own `diff -u` of `lib/flow_builder.dart` matches `0001-…patch` byte for byte. `LICENSE` and `CHANGELOG.md` are byte-equal. **4 negatives, all FAIL as they should:** `lib/` edited (M5) → "DIFFERS from the recorded patch"; `LICENSE` +1 byte → "DIFFERS"; an extra `lib/extra.dart` → "DIFFERS in other files"; `@pub_deps//:flow_builder` planted in `mc_feature_flow/BUILD.bazel` → listed. **Locks:** `pubspec.lock` differs from main only by the hosted flow_builder block. A structural JSON diff of `MODULE.bazel.lock` ([diff](verifier/logs/module-lock-structural-diff.txt)) shows 80 changes: 77 drop `flow_builder` from `lock_packages` lists, 3 remove the `pub_deps__flow_builder` and `pub_deps-android-flow_builder` repos and the `facts` entry, and 1 updates the `pubspec.lock` input hash, which equals `shasum -a 256 pubspec.lock` (`1a64c070…`). No other version or sha moved. **But** the check fails once this merges (D1) | **PASS** |

## Probes (mine; [`verifier/verifier_probe_test.dart`](verifier/verifier_probe_test.dart), run as a temporary `flutter_test` with `@pub_deps//:go_router`, never committed outside `documents/`)
Order matters. The two BASELINE cases run first, before any FlowBuilder has mounted in the process, so they answer through `WidgetsBinding._handleNavigationInvocation`.

| Probe | What | Result |
|---|---|---|
| BASELINE | Framework handler, recording delegate: `[[link, true, /a/b?q=1&r=x%20y#frag], [ioslink, true, miniclient://app/characters/6?tab=info#bio], [legacy, true, /legacy?z=2#f], [pop-handled, true, 1, 0], [pop-unhandled, false, 2, 1], [unknown, false], [withState, true, /s, st]]` | recorded |
| BASELINE go_router | `[[go-link, true, /items/7?tab=info#sec, 1], [go-ios, true, miniclient://app/items/8?x=1#y], [go-pop, true, /]]` | recorded |
| VPROBE1 | Flow mounted **with its inner page open**: a query+fragment link, then a second link straight after. Both reply `true` and arrive in order. The URI keeps `fragment == 'frag'` and `queryParameters == {q: 1, r: 'x y'}`. The inner page is still shown | PASS |
| VPROBE2 | After dispose, the full script equals the baseline (only `state` differs, as accepted) | PASS |
| VPROBE3 | Nested, inner pushed: pop 1 is taken by the innermost flow (inner detail gone, router 0 pops, reply `null`). Pop 2 **falls through while both flows are still mounted**: router pops = 1 and `SystemNavigator.pop` = 1, as the framework does | PASS (see note O1) |
| VPROBE4 | Two sibling flows; dispose the second. A link arrives (`true`, `/sib?a=1#b`). Flow one, still mounted, takes the first pop and the second falls through. After disposing all, the script equals the baseline | PASS |
| VPROBE5 | go_router: a link to `/flow` mounts a FeatureFlow with its inner page open. The go_router script then equals the go_router baseline. After re-mounting the flow, two links in a row: `/items/1?a=1`, then `/items/2#z` is shown | PASS |
| Same probes on **stock** 0.1.0 | Control ([log](verifier/logs/p2-probes-on-stock.log)) | VPROBE1, 2, 4 and 5 **FAIL**; the pop-only VPROBE3 and 3b behave **identically to the patched copy** |

## Mutations of the patch (`flow_navigation_channel_test`, uncached; [`scripts/mkmut.py.txt`](verifier/scripts/mkmut.py.txt))
| Mutant | Engineer's 6 tests | My probes |
|---|---|---|
| M0: stock 0.1.0 | **4 fail** | 4 fail |
| M1: forward only `Uri.parse(location).path` (query dropped) | **killed** (AC1 "while mounted") | — |
| M2: unknown method → `null` | **killed** (AC2 "unknown method") | — |
| M3: forward, but reply `null` | **survives**, 6/6 | **killed** (VPROBE1, 2, 4, 5) |
| M4: `popRoute` skips the interceptors | **killed** (AC2 nested, AC2 popRoute) | — |
| M5: fragment dropped (`location.split('#').first`) | **survives**, 6/6 | **killed** (VPROBE1, 2, 4, 5) |

## App-level evidence: the T-0033 R1 repro
`fleet/T-0033-universe-wiring` is reachable locally (head `ad8b82e`, not on `origin`). I merged it on top of `43e97a4` without committing:
- The only conflict was `MODULE.bazel.lock`. I took the T-0035 side and let Bazel re-resolve it. The merged `pubspec.lock` passes `pub get --enforce-lockfile`.
- I un-skipped T-0033's `links_after_flow_test` ("T-0033-AC4 a link sent to the running app opens its route after the characters list (a flow) is shown") and appended the R1 repro ([file](verifier/t0033_links_after_flow_test_unskipped_plus_R1.dart.txt)).

Results:
- **On T-0035 + T-0033** ([log](verifier/logs/t0033-R1-repro.log)): `VERIFIER before-flow link shown=1 grid=1 after-flow link shown=1`. Both cases PASS, including the post-flow link `miniclient://app/placeholder/43?from=verifier#x`.
- **The same, on stock** ([log](verifier/logs/t0033-R1-repro-on-stock.log)): both FAIL. "before-flow shown=0" because the first case had already mounted a flow in that process, which shows the hijack outlives the flow.
- **All app, feature and kit tests on the merged tree** ([log](verifier/logs/t0033-merged-app-tests.log)): **16/16 targets PASS** uncached, including `app_test` and `universe_sandbox_links_test`.
- **Afterwards:** `git reset --hard 43e97a4` and the scratch files were removed; the tree was clean apart from my evidence.

## Lint and format exemptions
- **Bazel lint:** the `no-dart-analyze` / `no-dart-format` tags sit on `//third_party/flow_builder:flow_builder` only. The query above shows no other new exempt target, and every first-party `flutter_library` / `flutter_test` is still analysed and format-checked by `build --config=lint`.
- **Format gate directories:** the format gate's list (`app feature spike utility tool/l10n_check tool/mc_arch_check`) is **unchanged from `T-0034-AC5_gates.sh`**. `third_party/` was never in it.
- **What sits in `third_party/`:** the only Dart under it is `third_party/flow_builder/lib/flow_builder.dart`, and the provenance check pins that directory to archive + patch, with an extra file failing (negative above).
- **Judgement:** the exclusion is narrow; no first-party code escapes.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none. Only `flow_navigation_channel_test.dart` was added. `feature_flow_test`, `flow_kit_test` and the `characters_list` tests have no diff against `origin/main`.
- **Lint suppressions added:** none first-party. The single `// ignore: null_check_on_nullable_type_parameter` in the diff is upstream's, verbatim from the archive.
- **Golden files updated:** none.
- **AC naming:** every AC has tests named `T-0035-ACn`:
  - AC1 ×2 and AC2 ×4 in `flow_navigation_channel_test`.
  - AC3 is covered by the unchanged existing tests, as the AC itself specifies.
  - AC4 by the `tool/checks/T-0035-AC4_*.sh` checks.
- **Unrelated changes:** none. The diff is the vendored package, the root `pubspec.yaml` workspace entry, the locks, `mc_feature_flow`'s dependency and new test, the two checks, and docs (task, F-0034, upstream draft, engineer evidence).

## Visual acceptance
Not applicable. This is a kit-level channel fix with no UI change.

## Issues found
1. **D1 (major, not an AC failure): `T-0035-AC4_provenance.sh` fails permanently as soon as T-0035 is on `origin/main`.**
   - **Where:** `tool/checks/T-0035-AC4_provenance.sh:49` requires `origin/main:pubspec.lock` to still contain the hosted `flow_builder:` block, and `:37` diffs the lock against `origin/main`.
   - **Effect:** after the merge, `:49` always sets `ok=0`. The report then prints **FAIL with every row green**. Any later lock change on a branch also trips `:37`.
   - **Why it matters:** `VENDORED.md:53-60` ("Checking the provenance", "Updating") tells maintainers to run this check when re-vendoring.
   - **Repro:** a copy of the script with `origin/main:` replaced by `HEAD:`, which simulates the post-merge state, gives rc 1 with all rows "identical / matches / byte-equal" ([log](verifier/logs/m-provenance-postmerge-sim.log)).
   - **Fix:** either split the evergreen part (archive sha, `lib/` = archive + patch, LICENSE) from the one-shot lock-delta part, or pin the lock comparison to the pre-T-0035 base `6e7eaaf` instead of `origin/main`.
2. **D2 (minor): the AC1/AC2 tests don't pin the `pushRouteInformation` reply or the fragment.**
   - **Where:** `utility/mc_feature_flow/test/flow_navigation_channel_test.dart:68-85`. `_send` discards the reply (`(_) {}`), and the URIs checked have no `#fragment`.
   - **Effect:** mutants M3 (reply `null`) and M5 (fragment dropped) survive all 6 tests.
   - **Why the reply matters:** iOS uses it. `FlutterEngine.mm:1631-1656` / `FlutterAppDelegate.mm:157-183` treat a non-`true` reply as "unhandled" and bounce universal links to the system.
   - **Coverage today:** the code is correct (my VPROBE1, 2, 4 and 5 kill both mutants).
   - **Suggested fix:** assert `reply == true` and a `#fragment` in the AC1 case.
3. **D3 (minor, integration): add/add conflict on the task file.** `documents/tasks/T-0035-flow-builder-deep-link-hijack.md` conflicts with `origin/main` `e867051`, which added the same file after this branch's base `6e7eaaf` (`git merge-tree` shows the conflict). It is trivial: the branch version is main's plus the Status, Log and Outcome. Merging T-0033 afterwards conflicts on `MODULE.bazel.lock`; re-resolve it, don't hand-merge.

## Notes for the Tech Lead
- **O1 (pre-existing upstream behaviour, unchanged by the patch, outside AC):**
  - flow_builder's `_pop` (`third_party/flow_builder/lib/flow_builder.dart:147-155`) at a flow's root calls `_navigator.pop()` on the flow's own last page before falling through. In VPROBE3 the inner flow's root page is gone after the fall-through `popRoute`.
  - With nested flows that are both pushed, the first `popRoute` is consumed by the hidden inner flow, with no visible change (VPROBE3b).
  - An intercepted `popRoute` replies `null` where the framework replies `true`.
  - All of this is identical on stock 0.1.0 ([log](verifier/logs/p2-probes-on-stock.log)).
  - On iOS, `popRoute` only comes from accessibility escape; Android is out of scope (Q-009). Worth a `pending-work.md` entry next to the upstream draft's `WidgetsBindingObserver` idea.
- **Engineer log:** the engineer's stock log cites `flow_navigation_channel_test.dart:209` for the unknown-method expectation, while the file has it at `:207`. The log came from an earlier revision. My own stock run reproduces the same 4/2 split at this SHA.
- **After T-0035 merges:** un-skip T-0033's `links_after_flow_test`. It passes on the combination, as shown above.
- **Reproducing my runs:** the scripts are in [`verifier/scripts/`](verifier/scripts/), saved as `.txt`.

---

## Re-verification at 4de779d
- **Commit verified:** `4de779d` (my `9c012f3`, then the `origin/main` merge `8489375`, then the fix round), on a detached HEAD in my own worktree. Output base `/tmp/mc-ob-T-0035-verifier`, shut down at the end.
- **Verdict:** **PASS**. D1 and D2 are fixed. D3 is gone: `origin/main` was merged, so the task file no longer conflicts. Evidence is in [`verifier/rv/`](verifier/rv/); the negatives script is [`scripts/neg.sh.txt`](verifier/scripts/neg.sh.txt).

### 1. Provenance split (D1)
- **Evergreen check:** `tool/checks/T-0035-AC4_provenance.sh` has no `origin` and no `git show`. It reads only the working tree. It passes at 4de779d ([report](verifier/rv/rv-provenance.md)): the patch is now 20 changed lines.
- **Simulated post-merge main where the lock moved for another reason:** I set `go_router` to 17.5.1 in `pubspec.lock` and appended a byte to `MODULE.bazel.lock`. The evergreen check **PASSES** ([report](verifier/rv/neg-evergreen-lock-moved-elsewhere.md)).
- **One-off check:** `tool/checks/T-0035-AC4_lock_delta.sh` sets `BASE=6e7eaaf` (`:14`); `origin/main` appears only in a comment. It passes at 4de779d ([report](verifier/rv/rv-lock-delta.md)): `pubspec.lock` is identical to the base minus the flow_builder block, and `MODULE.bazel.lock` equals the scrubbed base.

Negatives (all planted by me, restored after each run; tree clean afterwards):

| Check | Plant | Result | Failing row |
|---|---|---|---|
| evergreen | `lib/` edited (hunk 3 reverted) | **FAIL** | lib/ vs archive: DIFFERS from the recorded patch |
| evergreen | LICENSE +1 byte | **FAIL** | LICENSE: DIFFERS |
| evergreen | hosted `flow_builder:` block put back into `pubspec.lock` | **FAIL** | lock entries: 1 |
| lock delta | `pubspec.lock` go_router → 17.5.1 | **FAIL** | pubspec.lock: DIFFERS 223c223 |
| lock delta | `MODULE.bazel.lock` `pub_deps__go_router` version changed | **FAIL** | MODULE.bazel.lock: DIFFERS |
| lock delta | `MODULE.bazel.lock` `pub_deps__go_router` repo deleted | **FAIL** | MODULE.bazel.lock: DIFFERS |

### 2. Wider hosted-reference scan
Every plant makes the evergreen check fail and names the planted file:

| Plant | Result |
|---|---|
| `"@pub_deps//:flow_builder"` (quoted) appended to `tool/bazel/defs.bzl` | **FAIL**, `./tool/bazel/defs.bzl` |
| Unquoted `@pub_deps//:flow_builder` in a new `feature/zz_verifier_plant.bzl` | **FAIL**, that file |
| Unquoted, in a plain `BUILD` file (`utility/mc_feature_flow/BUILD`) | **FAIL**, `./utility/mc_feature_flow/BUILD` |
| Unquoted `@pub_deps//:flow_builder,` replacing the vendored dependency in `BUILD.bazel` | **FAIL**, `./utility/mc_feature_flow/BUILD.bazel` |
| `pubspec.yaml`: block form `flow_builder:` / `hosted: https://pub.dev` / `version: ^0.1.0` | **FAIL**, `./utility/mc_feature_flow/pubspec.yaml` |
| `pubspec.yaml`: inline `flow_builder: {hosted: https://pub.dev, version: ^0.1.0}` | **FAIL**, same file |

### 3. Mutants, re-run on the new `lib/`
Each mutant ran against `flow_navigation_channel_test` + `framework_navigation_baseline_test`, uncached ([logs](verifier/rv/)):

| Mutant | Result |
|---|---|
| M3: link reply `null` (survived before) | **killed**: 3 cases (AC1 link, AC2 after-dispose, AC2 nested) |
| M5: fragment dropped (survived before) | **killed**: same 3 cases |
| M1: query dropped | killed: 3 |
| M2: unknown method → `null` | killed: 3 |
| M4: `popRoute` skips the interceptors | killed: 2 |
| M6 (new, mine): intercepted pop answers `null` again (hunk 3 reverted) | **killed**: AC2 nested, AC2 popRoute |
| Stock 0.1.0 | **5 of 6 flow cases fail**; only the legacy `pushRoute` control passes |

The baseline target's 2 cases passed under every mutant and under stock. That is expected, since it doesn't depend on flow_builder.

### 4. Baseline target
- **Closure:**
  - `cquery 'somepath(//utility/mc_feature_flow:framework_navigation_baseline_test, //third_party/flow_builder)'` is **empty**, while the same query from `flow_navigation_channel_test` finds a path (positive control).
  - `deps()` contains no flow_builder, `mc_feature_flow` library, bloc or go_router target ([closure](verifier/rv/rv-baseline-closure.txt)). Its deps are `mc_ds_theme`, flutter, flutter_localizations and flutter_test only.
  - Its LCOV lists only the two test files and `change_notifier.dart`.
- **Constants:**
  - The shared constants are `frameworkReplies = [true, true, false, true]` (link, legacy `pushRoute`, unknown, router-handled `popRoute`) and `frameworkLocations = [fullLink, '/legacy?z=2#f']`.
  - They match my first-round baseline recording from the framework's own handler (same replies and URIs).
  - The flow tests' post-dispose case and the nested case's post-unmount part assert exactly `runScript == frameworkReplies` and `asStrings == frameworkLocations`.
  - Because the baseline is its own Bazel target, test order no longer matters.
- **Minor note, not a defect:** the router's `popHandles` defaults to `true`, so the "router doesn't handle it → `false` + `SystemNavigator.pop`" path isn't in the committed constants. My first-round VPROBE2 showed it identical anyway.

### 5. Intercepted `popRoute` answers `true` (hunk 3)
- **Code:** `third_party/flow_builder/lib/flow_builder.dart` `_popRoute` now returns `Future<dynamic>.value(true)` when an interceptor consumed the pop. That is the framework's answer (`handlePopRoute` → `true` when an observer handles it).
- **Tests:**
  - "T-0035-AC2 popRoute pops a pushed flow page before the router sees it (answered true) …" asserts `true` with `delegate.pops == 0`.
  - The nested case asserts the same.
  - M6 kills both.
- **Docs and patch agree with `lib/`:**
  - `0001-forward-pushRouteInformation.patch` holds 3 hunks: `pushRouteInformation` + unknown → `false`, intercepted pop → `true`, and `_pushRouteInformation`.
  - The evergreen check confirms `lib/` = archive + that patch byte for byte (20 changed lines).
  - `VENDORED.md` "What differs from the archive" lists items 1-3 to match. Its "Known limits" section records the accepted deviations and the unchanged upstream quirks (my O1).
- **Effect on the platforms:** on Android and iOS the `popRoute` reply isn't consumed (the embedders invoke it without a result), so the change is harmless there and matches the framework.

### 6. Cheap items
- **`^0.1.0` restored:** `utility/mc_feature_flow/pubspec.yaml` says `flow_builder: ^0.1.0` again, and it still resolves to the workspace member. `pub get --offline --enforce-lockfile` gave rc 0 with a clean tree.
- **`merge_lcov.py` moved:**
  - It now lives at `tool/checks/merge_lcov.py` (a `git mv`, identical content).
  - `T-0032-AC7_gates.sh`, `T-0034-AC5_gates.sh` and `T-0035-AC4_gates.sh` point at it, and no script references the old path.
  - **All three gate scripts PASS:** T-0035 ([report](verifier/rv/rv-T-0035-AC4_gates.md)), T-0034 ([report](verifier/rv/rv-T-0034-AC5_gates.md)), T-0032 ([report](verifier/rv/rv-T-0032-AC7_gates.md)). Exit codes are in `rv-gate-scripts-rc.txt`.
  - T-0034's report also lists `mc_test_utils` at 87 %. That is its pre-existing exemption.

### 7. Gates
| Gate | Result |
|---|---|
| `test --nocache_test_results --test_output=all //utility/mc_feature_flow/... //feature/characters/characters_list/...` | **9/9 targets** ([log](verifier/rv/rv-test-uncached.log)). The 8 T-0035 cases pass by name, including the new baseline target |
| `T-0035-AC4_gates.sh` | **PASS**. `test //...` 79/79 (touched packages uncached), `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, **both provenance checks**, coverage |
| Coverage, own parser (`mylcov.py`, after my own `coverage //utility/mc_feature_flow/...`) | `mc_feature_flow` **142/143 = 99.3 %** (missed `feature_flow.dart:213`, which this diff doesn't touch); `characters_list` hand-written **156/156** ([numbers](verifier/rv/rv-coverage-own-parser.txt)) |
| Final re-check at HEAD after the scratch merge was reset | `//utility/mc_feature_flow/...` uncached: 4/4 |

### T-0033 R1 repro, again
- **Setup:** `ad8b82e` (still `fleet/T-0033-universe-wiring`, local) merged on top of 4de779d without committing. The only conflict was `MODULE.bazel.lock`: I took the T-0035 side and let Bazel re-resolve. `pub get --enforce-lockfile` gave rc 0. I un-skipped `links_after_flow_test` and appended the R1 case.
- **Result** ([log](verifier/rv/rv-t0033-merged.log)):
  - `VERIFIER before-flow link shown=1 grid=1 after-flow link shown=1`.
  - T-0033-AC4 "a link sent to the running app opens its route after the characters list (a flow) is shown" PASSES.
  - **All 17 app, feature and kit targets PASS uncached.**
- **Afterwards:** `git reset --hard 4de779d`, the scratch files removed, and the tree clean apart from my evidence.

### Test integrity in the fix round
- **Changed test:** `flow_navigation_channel_test.dart` was rewritten. I checked that it is stronger, not weaker:
  - Every first-round assertion is still there in substance: link while mounted, legacy `pushRoute`, after dispose, nested, pop interception and fall-through, unknown method.
  - It adds the reply values, fragment, query, two links in a row, and comparison with the framework constants.
  - The order-dependent "before" control moved to the baseline target as "T-0035-AC1 control".
- **New test files:** `framework_navigation_baseline_test.dart` and the shared `navigation_channel_support.dart`.
- **Nothing else:** no test skipped or deleted elsewhere, no `// ignore:`, no golden updates.

### Issues at 4de779d
None blocking. The only observation is the minor `popHandles: true` note in §4.
