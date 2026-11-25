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
