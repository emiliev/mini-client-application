# Project Status

_Last updated: 2026-11-27 by Tech Lead_

| | |
|---|---|
| **Product** | An enterprise **Marvel app** in Tide's *Project Miniclient* "Lego" architecture: **169 modules** at S2, ≥ 500k LOC, BDD tests, iOS. It is the workload for **stress-testing and optimising `ai_rules_dart` / `ai_rules_flutter`** ([plan](plan/README.md), [Q-006](open-questions.md#q-006)) |
| **Phase** | Phase C complete (7 of 7 archetypes). **Phase D started (hybrid, PO 2026-11-27):** the `mcgen` generator plus hand-built features in parallel |
| **Health** | Amber: PO decisions Q-010 to Q-014 open (defaults allow Phase A to proceed); usage limits cap crew at 3 concurrent agents |
| **Code** | **The Marvel app boots on the iOS simulator** (`app/mini_client`), and the **first feature, `characters_list`**, is merged. About 30 packages (foundation, design system incl. paged lists/media/cards, mocked backend and fixtures, API client, feature flow, paging) and 75 test targets, all built and tested by Bazel 9.3.0 + Flutter 3.47.7. All codegen (freezed, json, go_router, gen-l10n, retrofit, injectable, BDD) runs as Bazel actions through 3 rules patches |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private); `origin/main` is the integration branch ([ADR-0004](adr/0004-git-integration-workflow.md)) |
| **Verification** | Lean since 2026-11-27 ([ADR-0015](adr/0015-lean-verification.md)): no feature goldens, ~15 targeted mutants, correctness-only Verifiers |
| **CI** | GitHub Actions (`.github/workflows/ci.yml`, `tool/ci/ci.sh`, 11 gates) on `main`, `fleet/**`, PRs and on demand; cold 44 min, warm 25 min (T-0068) |
| **Merge gate** | Fresh Verifier PASS + clean review + TL re-verifies the merge result ([ADR-0006](adr/0006-verification-strategy.md)) |
| **Active crew** | none |

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
- **T-0075 and T-0076 merged: the `mcgen` FW and DB archetypes.** 5 of 7 feature archetypes are templated (LD, SC, SR, FW, DB), and all 8 modules regenerate byte for byte on `main`.
- **T-0074 merged: `mcgen wire` and `buildgen`** (P2-08). Generated BUILD files (all 11 features match), `flow_scope.dart`, workspace members, the app wiring list and generated wiring groups; a `/catalogue` route lists generated flows. ADR-0018 accepted.
- **T-0072 merged: `mcgen` section-detail archetype.** `comics_details` and `characters_details` regenerate byte for byte. Three of seven feature archetypes are templated (LD, SR, SC).
- **T-0073 merged: `mcgen` search archetype.** `discovery_search` (grouped) and `characters_search` (paged, facets) both regenerate byte for byte.
- **T-0069 merged: the first `mcgen` archetype (list-detail, P2-04).** `characters_list` regenerates byte for byte from its spec (56 files), and a throwaway second list-detail module generates and passes under Bazel. ADR-0017 accepted.
- **T-0071 merged: character search.** A name-prefix search with sort and team filters, recent searches and paging, reached from the characters list's app bar.
- **T-0070 merged: a Settings screen.** It has the account (sign in or out), Appearance with the current theme, and About. Back goes Appearance → Settings → home.
- **T-0068 merged: CI.** Every push to `main` runs the 11 merge gates on a GitHub macOS runner, with Bazel caches. It proved green on cold and warm caches and red on a broken test.
- **T-0066 merged: real sign-in and the `/me/**` guard.** A sign-in screen with demo accounts. Signed-out links to `/me/**`, `/library/**` and `/store/checkout` go to sign-in, then on to the target. Every "sign in to continue" uses it, and the fixture sheet is gone. A narrow auth Verifier passed it.
- **T-0067 merged: the character profile** (F002). Portrait, bio, a stats chart, the character's comics and a favourite now sit behind "See full profile". The comic page's favourite got the same race fixes.
- **T-0065 merged: the `tool/mcgen` core** (P2-01). Spec model and lint, seeded RNG, deterministic writer, manifest, keep regions, clobber guard, `gen --check`, and import resolution. The per-archetype templates (P2-04 to P2-07) come next. ADR-0016 accepted.
- **T-0063 merged: `settings_appearance`, the ST exemplar.** Theme mode, density and reduce motion apply to the whole app at once, are saved on the device, and sync to the signed-in account (`mc_appearance`, ADR-0013).
- **T-0064 merged: `trivia_quiz`, the IX exemplar.** Timed 10-question rounds with a pure-Dart scoring engine that agrees with the server's, a 50/50 hint, pause on background, and results charts. ADR-0014 accepted. It was the first merge under ADR-0015.
- **T-0062 merged:** tooling hygiene. The e2e app installs as `com.emiliev.miniclient` (Q-004); there is one shared format gate (`tool/checks/lib/format_gate.sh`); `e2e_ios.sh` accepts any role and explains how to prepare a raw tree; the sign-in sheet handle is pinned.
- **T-0056 merged: `store_home`, the DB exemplar.** A store front with banners, deals, categories, featured products and a cart summary. Each section loads, fails and retries on its own, and a category opens a paged list. It is the first feature behind a feature flag and with analytics. ADR-0012 accepted.
- **T-0061 merged:** identity preferences (theme mode, density, reduce motion) are saved per user on the mocked server, with optimistic concurrency, ready for the ST exemplar.
- **T-0060 merged:** the trivia backend for the IX exemplar. Seeded 10-question rounds come out the same every run; the server scores answers and keeps best scores.
- **T-0058 merged:** `mc_ds_overlays`. Dialogs, sheets, menus, tooltips and toasts come from one DS family, and features may no longer call `showDialog` and friends directly. The sign-in sheet uses it.
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
- **Third wave (2026-11-28):**
  - T-0072: `mcgen` SC archetype
  - T-0073: `mcgen` SR archetype
  - T-0074: `mcgen wire`/`buildgen` (P2-08)
- **Next:**
  - ST and IX archetypes, then P-128 (a) and (e): route specs for the hand-written groups, and wire routing for FW and DB (needed before batches);
  - P-123 (CI speed);
  - then the Phase E batches.

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
