# Project Status

_Last updated: 2026-11-23 by Tech Lead_

| | |
|---|---|
| **Product** | An enterprise **Marvel app** in Tide's *Project Miniclient* "Lego" architecture: **169 modules** at S2, ≥ 500k LOC, BDD tests, iOS. It is the workload for **stress-testing and optimising `ai_rules_dart` / `ai_rules_flutter`** ([plan](plan/README.md), [Q-006](open-questions.md#q-006)) |
| **Phase** | Planning: the plan is assembled and in **verification** (wave 3). Execution starts at Phase A (de-risk spikes) |
| **Health** | Amber: the plan is not yet verified; PO decisions Q-010 to Q-014 are open; agents keep hitting usage limits, so concurrency is capped at 3 |
| **Code** | Docs plus T-0012 scripts, on a branch that hasn't merged yet |
| **Remote** | [github.com/emiliev/mini-client-application](https://github.com/emiliev/mini-client-application) (private); `origin/main` is the integration branch ([ADR-0004](adr/0004-git-integration-workflow.md)) |
| **Merge gate** | Fresh Verifier PASS + clean review + TL re-verifies the merge result ([ADR-0006](adr/0006-verification-strategy.md)) |
| **Active crew** | T-0012 Engineer (review fixes); plan Verifiers V1 to V3 |

## Now
- [T-0013](tasks/T-0013-enterprise-plan.md) Enterprise plan: **In Verification**
- [T-0012](tasks/T-0012-ios-sim-e2e-runner.md) Simulator e2e runner: **In Progress**, fixing 4 important review findings

## Next
Phase A de-risk spikes ([plan §5](plan/README.md#5-delivery-roadmap)): toolchain + Dart version (P3-01) → retrofit / injectable / BDD codegen shims (P3-03 to P3-05) → go_router + l10n + app shell (P3-07) → flow_builder on 3.47.7 (P1-04), alongside the perf harness (P4-01 to P4-03) and `tool/loc` (P2-02).

## Decisions needed from the PO
[Q-010](open-questions.md#q-010) LOC definition · [Q-011](open-questions.md#q-011) release AOT goal split · [Q-012](open-questions.md#q-012) budget16 hardware / VM · [Q-013](open-questions.md#q-013) GitHub access for upstream · [Q-014](open-questions.md#q-014) Apple Developer team · [Q-004](open-questions.md#q-004) bundle id spelling · [Q-007](open-questions.md#q-007) store release vs Marvel IP

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
