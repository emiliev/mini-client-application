# T-0035: Deep links survive a mounted `FeatureFlow` (flow_builder takes over the navigation channel)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-25 `1671aad`; Verifier PASS `16bd800`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0035-flow-deep-links` |
| Created | 2026-11-25 |
| Depends on | T-0022 (`mc_feature_flow` on flow_builder 0.1.0), T-0034 |
| Blocks | T-0033 merge |
| Related | F-0018 (flow_builder spike), F-0020, T-0021-AC3, R29, ADR-0008 (vendoring / patching precedent: T-0028) |

## Problem (T-0033 Verifier, R1, 2026-11-25)
The T-0033 Verifier found that once any `FlowBuilder` has mounted, a deep link sent to the running app does nothing. Cold-start links and links that arrive during boot still work.

flow_builder 0.1.0 (`flow_builder.dart:104,350,357-365`) replaces the framework's `flutter/navigation` method-call handler and never restores it. Its handler only knows `popRoute` and `pushRoute`, so it drops `pushRouteInformation`, which iOS sends for deep links. This breaks T-0021-AC3 in the real app as soon as `characters_list` is on screen.

Reproduced under Bazel: `before-flow link shown=1 grid=1 after-flow link shown=0`.

## TL decision
Fix it at the kit level, so no feature can trip over it.
- **Preferred:** vendor flow_builder 0.1.0 as `third_party/flow_builder` and point pub and Bazel at the vendored copy. Precedent: the injectable generator vendored in T-0028. Change it as little as possible: the channel handler must hand every method it doesn't own (at least `pushRouteInformation` and `pushRoute`) to the framework's `WidgetsBinding` behaviour, and must restore the original handler on dispose.
  - Record provenance in `VENDORED.md`: version, archive sha256, and the diff.
  - Draft an upstream issue in `documents/upstream/U-X-flow_builder-navigation-channel/`.
- **Alternative:** if vendoring is unworkable under rules_flutter's pub hub, fix it inside `mc_feature_flow`, for example by re-installing a forwarding handler after the `FlowBuilder` mounts. Write down why.
- iOS only (Q-009). Android back-button handling through the channel is out of scope, but don't make it worse than flow_builder already does.

## Acceptance criteria
- **T-0035-AC1:** A widget test in `mc_feature_flow` mounts a real `FeatureFlow`. It then delivers a `pushRouteInformation` message through `SystemChannels.navigation` (the framework's real path, via `TestDefaultBinaryMessenger`) to a `MaterialApp.router`. The router must receive the location. The test fails on stock flow_builder 0.1.0 (show it).
- **T-0035-AC2:** After the flow is disposed, `flutter/navigation` behaves exactly as without a flow: links and `popRoute` work. A flow nested inside another flow also works.
- **T-0035-AC3:** The existing `mc_feature_flow` and `characters_list` tests are unchanged and green. Back gestures and edge swipe in flows work as before (F-0018 probes).
- **T-0035-AC4:**
  - Provenance is recorded: the vendored `lib/` equals the pub.dev archive except for the documented diff.
  - The upstream issue is drafted.
  - The gates are green: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format.
  - The locks are re-resolved, not hand-merged, and the only change is flow_builder's source.

## Log
- 2026-11-25: Created (TL) from the T-0033 Verifier's blocker R1.
- 2026-11-25: Engineer. Tests first: `utility/mc_feature_flow/test/flow_navigation_channel_test.dart` (6 cases) against stock flow_builder 0.1.0: 4 fail, 2 pass as controls ([ac1-stock log](../evidence/T-0035/engineer/ac1-stock-flow_builder-0.1.0-test.log)). Then vendored 0.1.0 as `third_party/flow_builder` (pub workspace member, Bazel `flutter_library`, `VENDORED.md`, `0001-forward-pushRouteInformation.patch`) and pointed `mc_feature_flow` at it; all 6 pass, and the existing `mc_feature_flow` cases pass unchanged. Locks re-resolved (`fvm flutter pub get --offline`; Bazel rewrote `MODULE.bazel.lock`): the only change is flow_builder's hosted entry going away. Upstream draft `U-X-flow_builder-navigation-channel`, finding F-0034.
- 2026-11-25: Engineer fix round after Verifier PASS (`9c012f3`), merged `origin/main`. (1) Provenance check split: evergreen `T-0035-AC4_provenance.sh` (working tree only) and one-off `T-0035-AC4_lock_delta.sh` pinned to `6e7eaaf`; (2) hosted-reference scan widened (BUILD, BUILD.bazel, *.bzl, quoted or not; pubspec sources; lock entry); (3) the channel test asserts the `true` reply and a link with query and fragment, mutants killed; (4) framework baseline moved to its own target `framework_navigation_baseline_test` and constants; (5) `flow_builder: ^0.1.0` restored; (6) `merge_lcov.py` moved to `tool/checks/` (P-071); (7) an intercepted `popRoute` answers `true`, quirks in F-0034 §7. Evidence: [negatives.md](../evidence/T-0035/engineer/negatives.md), [mutants](../evidence/T-0035/engineer/mutants/), [ac4-gates.md](../evidence/T-0035/engineer/ac4-gates.md).

## Outcome
**Engineer done**, awaiting a fresh Verifier. Alternative (fix inside `mc_feature_flow`) not needed; reasoning in F-0034 §2 and §3.

| AC | Evidence | Result |
|---|---|---|
| T-0035-AC1 | `flow_navigation_channel_test` cases named `T-0035-AC1 ...`; red on stock: [log](../evidence/T-0035/engineer/ac1-stock-flow_builder-0.1.0-test.log) | PASS (red on stock, green vendored) |
| T-0035-AC2 | cases `T-0035-AC2 ...`: after dispose, nested flows, popRoute interception and fall-through, unknown method answers `false` | PASS |
| T-0035-AC3 | no existing test file changed (`git diff origin/main -- '*_test.dart'` lists only the new file); `feature_flow_test` (T-0022-AC5 edge swipes), `flow_kit_test`, and all 8 `characters_list` targets green | PASS |
| T-0035-AC4 | [ac4-provenance.md](../evidence/T-0035/engineer/ac4-provenance.md) (archive sha256, `lib/` = archive + patch, LICENSE equal, lock diff = the flow_builder block; fails when `lib/` is edited, checked) and [ac4-gates.md](../evidence/T-0035/engineer/ac4-gates.md) (`test //...` 78 targets pass, lint, `mc_arch_check`, `rules_fork.sh check`, format, l10n_check, coverage mc_feature_flow 142/143 = 99.3 %) | PASS |

Notes for the TL:
- **Deviation from the decision text:** the framework's handler cannot be captured, so it is not "restored" on dispose. flow_builder's handler stays installed and forwards to the same `WidgetsBinding` entry points (F-0034 §2). `pushRouteInformation.state` is dropped (iOS sends none). Alternative, if you want it exact: wrap `PlatformDispatcher.onPlatformMessage` (bigger patch, and the test messenger bypasses it).
- The vendored target has `no-dart-analyze` and `no-dart-format` tags (F-0034 §4); `third_party/` is excluded from the format gate. No test deleted, skipped or weakened; no `// ignore:` added.
- Not run: the T-0033 simulator repro (`app/` is T-0033's); the engineer proof is the widget test through the real messenger path.

## Merge (TL)
- 2026-11-25: Verifier PASS `9c012f3`. The T-0033 R1 repro passes with the vendored copy (`after-flow link shown=1`). `/code-review` and the Verifier found that the provenance check would go red after merge (it compared against the moving `origin/main`), plus weak reply and fragment asserts and an order-dependent baseline. TL decision: not restoring the framework handler and dropping `state` are accepted, documented deviations. Fixed in `4de779d`: an evergreen provenance check plus a pinned lock-delta check, a wider scan, a baseline target, and an intercepted `popRoute` that replies `true`. Re-verify PASS `16bd800`. The TL merged `--no-ff`; on the merge result `check` passed with 3 patches, 79/79 tests, lint was clean, `mc_arch_check` reported OK and the evergreen provenance check passed.
- Follow-ups: P-075 (flow_builder pop quirks).
