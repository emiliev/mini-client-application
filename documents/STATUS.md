# Project Status

_Last updated: 2026-11-23 by Tech Lead_

| | |
|---|---|
| **Product** | An enterprise **Marvel app** in Tide's *Project Miniclient* "Lego" architecture: **169 modules** at S2, ≥ 500k LOC, BDD tests, iOS. It is the workload for **stress-testing and optimising `ai_rules_dart` / `ai_rules_flutter`** ([plan](plan/README.md), [Q-006](open-questions.md#q-006)) |
| **Phase** | Phase A/B: foundation **done**; next is the first feature (`characters_list`) plus the codegen shims (retrofit, injectable, BDD) |
| **Health** | Amber: PO decisions Q-010 to Q-014 open (defaults allow Phase A to proceed); usage limits cap crew at 3 concurrent agents |
| **Code** | **The Marvel app boots on the iOS simulator** (`app/mini_client`): 24 packages (foundation utilities, design system, mocked backend and fixtures, API client, feature flow), 39 test targets, all built and tested by Bazel 9.3.0 + Flutter 3.47.7 |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private); `origin/main` is the integration branch ([ADR-0004](adr/0004-git-integration-workflow.md)) |
| **Merge gate** | Fresh Verifier PASS + clean review + TL re-verifies the merge result ([ADR-0006](adr/0006-verification-strategy.md)) |
| **Active crew** | None (between waves) |

## Now
- Foundation wave done: T-0017 to T-0023 and T-0021 merged.

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
- Crew models: Opus for planning, rules work and verification; Sonnet for engineering; Haiku for bulk batches. At most 3 agents at once; no crew during perf windows.
