# Project Status

_Last updated: 2026-11-27 by Tech Lead_

| | |
|---|---|
| **Product** | An enterprise **Marvel app** in Tide's *Project Miniclient* "Lego" architecture: **169 modules** at S2, ≥ 500k LOC, BDD tests, iOS. It is the workload for **stress-testing and optimising `ai_rules_dart` / `ai_rules_flutter`** ([plan](plan/README.md), [Q-006](open-questions.md#q-006)) |
| **Phase** | Phase C (exemplars): **4 of 7 archetypes done**: LD `characters_list`, SC `comics_details`, SR `discovery_search`, FW `library_reading_list_editor`. Remaining: DB, ST, IX, then the P1-24 bricks |
| **Health** | Amber: PO decisions Q-010 to Q-014 open (defaults allow Phase A to proceed); usage limits cap crew at 3 concurrent agents |
| **Code** | **The Marvel app boots on the iOS simulator** (`app/mini_client`), and the **first feature, `characters_list`**, is merged. About 30 packages (foundation, design system incl. paged lists/media/cards, mocked backend and fixtures, API client, feature flow, paging) and 75 test targets, all built and tested by Bazel 9.3.0 + Flutter 3.47.7. All codegen (freezed, json, go_router, gen-l10n, retrofit, injectable, BDD) runs as Bazel actions through 3 rules patches |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private); `origin/main` is the integration branch ([ADR-0004](adr/0004-git-integration-workflow.md)) |
| **Merge gate** | Fresh Verifier PASS + clean review + TL re-verifies the merge result ([ADR-0006](adr/0006-verification-strategy.md)) |
| **Active crew** | T-0056 (Opus, review round), T-0058 (Sonnet, review round), T-0060 (Sonnet) |

## Now
- Foundation wave done: T-0017 to T-0026 merged.
- **T-0027 merged:** retrofit codegen runs in Bazel through patch 0001, byte-identical to build_runner. New rule R30: freezed models spell out `@Freezed(fromJson: true, toJson: true)`.
- **T-0028 merged:** injectable codegen runs in Bazel (patch 0002), byte-identical to build_runner, with the aggregate step cached across body edits.
- **T-0029 merged:** `.feature` files generate AC-tagged widget tests in Bazel (patch 0003). **No generator needed the build_runner fallback (R28).**
- **T-0030 merged:** `mc_paging` (paging controller, debounce, search history) and pure-Dart `mc_media`.
- **T-0031 merged:** the paged grid and list, `McImage` and `McMediaCard`, with 80 goldens across 4 themes and 2 text scales.
- **T-0032 merged: `characters_list`, the first Marvel feature**, is on `main`. It has a paged grid with bundled art and an in-flow preview; 75/75 tests, 100 % coverage, all generated code is byte-identical to build_runner's, and no codegen fallback was needed.
- **T-0034 merged:** the exemplar now matches plan 01's code shapes, with no workarounds. Flows have an automatic back button, and the base URL is safe in release.
- **T-0035 merged:** flow_builder is vendored with a patch so that deep links keep working once a flow is on screen (upstream issue drafted).
- **T-0033 merged: `characters_list` is in the app.** Home → Characters → paged grid → preview → "See full profile" (placeholder) on the iOS simulator, with back navigation and `miniclient://app/characters` deep links (cold, during boot and while running). A `universe_sandbox` app opens straight on the list.
- **T-0036 + T-0037 merged:** `McFlowBackButton` is correct in every navigation state the bricks will hit (pushed or root flows, deep-link stack changes, drawers, sheets, nested navigators), with flow_builder patch changes 4 and 5.
- **SC prerequisites merged:** comics fixtures (T-0038), the auth slice with session, bearer refresh and identity fixtures (T-0039), and DS navigation (T-0040).
- **T-0042 merged:** `tool/ide_sync` puts generated code in the checkout, so the IDE, `fvm flutter run`, the debugger and hot reload work (README "Developing").
- **T-0041 merged: `comics_details`, the second exemplar (SC).** A comic's page with cover, facts (localised), creators, cast, and a favourite that asks you to sign in. It is reachable from the characters preview and by `miniclient://app/comics/<id>`.
- **SR/FW prerequisites merged:** search fixtures (T-0043), DS inputs (T-0044), the forms and wizard kit (T-0045), library fixtures (T-0047).
- **T-0059 merged:** `mc_ds_charts`. Bar, line, donut, radar and timeline charts are themed, accessible and drawn the same way every time, with no chart package (the IX prerequisite).
- **T-0055 merged:** the e2e script can no longer report PASS for a target whose app didn't build (`flutter drive` exits 0 and runs the previous target's app). The full suite was re-baselined, 11/11.
- **T-0057 merged:** the async-guard paths of `AppFlows` are pinned, so the `/me/**` guard can start.
- **T-0054 merged:** a result-returning screen always hands back exactly once: after router reloads, same-frame links and overlays. The not-found page has Back and Go home. P-110 (async-guard tests) must come before the sign-in guard.
- **T-0052 merged:** `mc_feature_flags`. Typed flags and experiments are evaluated the same way every time, work offline from cache, take dev overrides, and never block boot. The mocked `/v1/flags` endpoint is in `mc_fixtures_platform`.
- **T-0053 merged:** `mc_analytics`. Screens and events are tracked through one facade, and nothing is delivered without consent (P1-05 AC4). There is no network sink (P-004). Every app route now has a name.
- **T-0050 merged:** an authenticated write never goes out under another user's token, even if the user switches while it is being sent (P-083). The favourite button ignores a tap from a screen that hasn't reloaded after a switch.
- **T-0049 merged:** a cold deep link to any entity screen now has home underneath it, so Back goes home (details go via the list). Home's New and Edit buttons keep working after a link replaces the editor. Follow-ups P-094 to P-098 (P-094 before the auth guard).
- **T-0051 merged:** `mc_fixtures_commerce`, the store backend for the DB exemplar: sections, a per-user cart in integer cents, stacking promotions.
- **T-0048 merged: `library_reading_list_editor`, the FW exemplar.** A 3-step wizard creates or edits a reading list; the result is returned to the caller (the flow-result pattern) and home shows "List created".
- **T-0046 merged: `discovery_search`, the SR exemplar.** Debounced search across characters and comics, grouped results, type chips, recent-search history, and a Search entry on home with a `miniclient://app/search?q=` link.
- Resumed 2026-11-27.
- **Next, in order:**
  1. DB prerequisites done (`mc_feature_flags`, `mc_analytics`, commerce fixtures). Next: the DB exemplar (T-0056, in progress) `store_home` (P1-21) on `mc_fixtures_commerce`.
  2. ST/IX prerequisites: `mc_ds_overlays` (T-0058, in progress) and `mc_ds_charts` (T-0059, done), trivia fixtures (T-0060, in progress), identity preferences for ST (next).
  - The `/me/**` auth guard is **deferred until the sign-in feature exists**. It needs a `/auth/sign-in?from=` route; today sign-in is the temporary fixture sheet (P-044), and the editor gates sign-in itself. P-110 is ready for it.
  3. ST (`settings_appearance`) and IX (`trivia_quiz`) exemplars, then the P1-24 bricks.

## Next
Phase A de-risk spikes ([plan §5](plan/README.md#5-delivery-roadmap)): toolchain + Dart version (P3-01) → retrofit / injectable / BDD codegen shims (P3-03 to P3-05) → go_router + l10n + app shell (P3-07) → flow_builder on 3.47.7 (P1-04), alongside the perf harness (P4-01 to P4-03) and `tool/loc` (P2-02).

## Decisions needed from the PO
[Q-010](open-questions.md#q-010) LOC definition · [Q-011](open-questions.md#q-011) release AOT goal split · [Q-012](open-questions.md#q-012) budget16 hardware / VM · [Q-013](open-questions.md#q-013) GitHub access for upstream. Defaults apply meanwhile. Answered 2026-11-23: Q-004 (bundle id `com.emiliev.miniclient`), Q-007 (no store release now), Q-014 (no physical devices until the PO calls for them).

## Recent decisions
- [ADR-0007](adr/0007-tide-miniclient-architecture.md) Tide Miniclient architecture and stack (with recorded deviations)
- [ADR-0008](adr/0008-bazel-with-ai-rules.md) Bazel with pinned ai_rules (patch queue, codegen shims)
- [ADR-0009](adr/0009-exemplar-first-generation-and-loc.md) Exemplar-first generation and the LOC metric
- [ADR-0010](adr/0010-testing-tiers-and-coverage.md) Tide testing tiers, BDD AC tags, 90 % coverage
- [Plan conflict resolutions R1 to R27](plan/README.md#4-conflict-resolutions-tl-decisions)

## Key facts for anyone joining
- Read [plan/README.md](plan/README.md) first, then the section for your task.
- Toolchain target: Flutter **3.47.7** (`.fvmrc`; FVM's global is 3.47.8 and stays untouched), Bazel **9.3.0** via `tool/bazelw`, rules pinned (ADR-0008). iOS only.
- Machine: M4 Pro, 14 cores, 48 GB. "budget16" is simulated (plan 04).
- Crew models (ADR-0011): TL and `/code-review` on Opus; engineers on Sonnet (Opus for rules patches and first exemplars); Verifiers tiered Opus/Sonnet by risk; Haiku for mechanical work. Code review runs before the Verifier. At most 3 agents at once; no crew during perf windows.
