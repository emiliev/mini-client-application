# T-0013: Enterprise-scale plan (Tide architecture × Bazel stress test)

| Field | Value |
|---|---|
| Status | Done (2026-11-23) |
| Owner | Tech Lead (orchestrating Researchers → Planners → Verifiers) |
| Branch | TL branch → `main` (docs only) |
| Created | 2026-11-22 |
| Updated | 2026-11-22 |
| Depends on | Q-006 (answered) |
| Related | ADR-0005, ADR-0006, Q-006, `documents/research/`, `documents/plan/` |

## Goal
A complete, verified plan for building an enterprise Marvel app that follows Tide's Project Miniclient architecture and stack: 100+ modules, BDD tests, 500k to 1M LOC minimum, built with Bazel through `ai_rules_dart` / `ai_rules_flutter`. The plan serves the end goal of stress-testing, profiling and optimising those rules (accurate caching, minimal incremental rebuilds, RAM-optimal AOT and JIT, with 5 to 10M LOC feasible on 16 GB), and of reporting the issues found upstream.

## Acceptance criteria
- **T-0013-AC1:** Given the six Tide articles, then `documents/research/tide-miniclient/` captures the architecture, the stack and the codegen inventory, citing article sections.
- **T-0013-AC2:** Given both rules repos, then `documents/research/bazel-rules/` documents their API, compilation model, codegen support, perf tooling and limitations, citing file paths.
- **T-0013-AC3:** Given the research, then `documents/plan/` holds an assembled plan: a module catalogue of at least 100 modules, a LOC budget of at least 500k, the Bazel integration, the profiling and optimisation programme with an upstream-reporting workflow, the BDD testing approach, and a phased delivery roadmap that fleet waves can execute.
- **T-0013-AC4:** Given the plan, when fresh Verifier agents audit it against the Tide articles, then every deviation is either fixed or recorded as an intentional, justified deviation.
- **T-0013-AC5:** Given the plan, then ADRs record the major decisions, and BOARD and STATUS reflect the new task breakdown.

## Plan
1. **Wave 1, research (4 agents in parallel):** Tide core architecture; Tide app, navigation and testing; `ai_rules_dart`; `ai_rules_flutter`.
2. **Wave 2, planning (parallel agents):** architecture and module catalogue; scale and codegen; Bazel integration; profiling and optimisation; testing and BDD; delivery roadmap.
3. **Assembly (TL):** reconcile conflicts and write `documents/plan/README.md`, ADRs and tasks.
4. **Wave 3, verification (fresh agents):** conformance to the Tide articles, plus Bazel feasibility against the rules repos.
5. **Fix and finalise:** apply the verification findings.

## Log
- 2026-11-22: Created from the PO request. Medium blocks direct fetches (403), but the publication's RSS feed has the full text of all six Miniclient articles. Extracted locally with the 5 diagrams. Both rules repos are cloned read-only (`ai_rules_dart` HEAD `be4e99f`, `ai_rules_flutter` HEAD `876e263`). Bazel 9.2.0 is installed; the machine is an M4 Pro with 14 cores and 48 GB (so the 16 GB budget must be simulated). Wave 1 dispatched.
- 2026-11-22: Wave 1 done. Four research docs are in `documents/research/` (about 26k words in total). Two agents were cut off by a usage-limit pause, but both had finished writing. Key facts: "feature flow" is Tide's `feature_flow` navigation utility (state management is flutter_bloc); l10n is absent from the articles; rules_dart curates freezed and json_serializable but not injectable, retrofit or bdd_widget_test, and its builder shim isn't consumer-visible; outline cutoff needs Dart 3.13 (Flutter 3.47.x); upstream perf benches are pure Dart (rules_dart) or reach 500k LOC (rules_flutter); AOT and JIT peak RSS at scale is unmeasured upstream.
- 2026-11-22: Planning brief (`documents/plan/00-planning-brief.md`, decisions D1 to D12) written. Wave 2 dispatched with 5 planners: P1 architecture and catalogue, P2 generation and scale, P3 Bazel integration, P4 profiling, optimisation and upstream, P5 testing and BDD. The TL writes the delivery roadmap at assembly.

- 2026-11-22/23: Wave 2 ran with interruptions (usage-limit pauses three times; agents resumed one at a time). All five sections were written: 01 (169 modules, ~634k LOC), 02 (mcgen, S0 to S4, edit corpus), 03 (pins, patch queue, codegen shims), 04 (KPIs, budget16, oracles, 23 experiments, upstream pipeline), 05 (Tide tiers, BDD AC tags, Bazel test targets).
- 2026-11-23: TL assembled `documents/plan/README.md`: resolutions R1 to R27, roadmap Phases A to H, superseded tasks. Wrote ADR-0007 to ADR-0010 and raised Q-010 to Q-014. Wave 3 (V1 to V3) dispatched.

- 2026-11-23: Wave 3 ran: V1 (14 findings), V2 (16), V3 (19), with 0 blockers. A plan-editor fix pass resolved all 49 (47 fixed, 1 accepted deviation V2-13, 1 spike V3-01 → P3-01). Changed R4, R6, R7, R13 to R17, R19, R25 and R28; added R29 (boot and deep links). Leftovers: P-018, P-019.

## Outcome
- **AC1, AC2:** `documents/research/` (4 docs).
- **AC3:** `documents/plan/` (README + 5 sections): 169 modules, about 634k LOC at S2, S3 at about 1M, S4 synthetic 5M and 10M; Bazel integration; profiling and upstream programme; BDD testing; Phases A to H.
- **AC4:** `documents/plan/reviews/V1..V3` with a Resolution column; every finding resolved.
- **AC5:** ADR-0007 to ADR-0010; BOARD and STATUS updated; Q-010 to Q-014 raised.
- **Next:** Phase A de-risk spikes.
