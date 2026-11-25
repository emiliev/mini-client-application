# T-0035: Deep links survive a mounted `FeatureFlow` (flow_builder takes over the navigation channel)

| Field | Value |
|---|---|
| Status | In Progress |
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
