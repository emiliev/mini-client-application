# T-0016: Perf harness foundations: harness, ingestion, macOS sampler (P4-01 to P4-03, scoped)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Sonnet, fresh; low-risk tooling) |
| Branch | `fleet/T-0016-perf-harness` |
| Created | 2026-11-23 |
| Depends on | — (Phase A, wave A1). The ACs that need the S0 app (P4-01 AC5, P4-02 AC1, P4-03 AC2) are **deferred** to a later task |
| Related | [plan 04 §5, §6, §11, P4-01 to P4-03](../plan/04-profiling-optimization-upstream.md), R20, R21 |

## Goal
The measurement foundation, independent of our app: environment capture and the perf lock, execution-log and profile ingestion, and the process-tree memory sampler that reports `phys_footprint` (plan 04 KD-2).

## Scope
- **In:** `tool/perf/` (Python 3.9 stdlib, run as `python3 -I`): `bench.py` (the `flags` subcommand), `env.py`, `lock.py` (`/tmp/mc-perf.lock`, intruder detection), ingestion of compact execution logs (via Bazel's converter, or a documented fallback), BEP and trace profiles, the sampler, and self-tests. A tiny **genrule-only** test workspace under `tool/perf/testdata/` to produce real logs.
- **Out:** budget16 ballast (P4-04), scenario runner (P4-05), anything needing rules_dart / rules_flutter.
- **Files / areas:** `tool/perf/` only.

## Acceptance criteria
- **T-0016-AC1** (P4-01 AC1): Given the installed Bazel, when `bench.py flags` runs, then every flag in `tool/perf/profiles/` and plan 04 §6.3 is reported available or missing, and a missing flag fails the run by name.
- **T-0016-AC2** (P4-01 AC2): Given another run holding the lock, or a foreign Bazel server or a booted Simulator, when a timed run starts, then it refuses. If an intruder appears mid-run, the run is marked contaminated.
- **T-0016-AC3** (P4-01 AC3, AC4): Given any run, then `env.json` records the repo SHA, Bazel, Flutter, Dart, Xcode and macOS versions, machine id, power source, thermal state, profile and `bench_version`. Calibration drift above 5 % is flagged `machine_drift`.
- **T-0016-AC4** (P4-02 AC2, AC3): Given two compact logs of the test workspace with one input edited between them, when diffed, then spawns pair 1:1 and exactly the spawns whose input digests changed are reported. Ingestion streams (no full sort), and peak RSS stays bounded on a synthetic large log.
- **T-0016-AC5** (P4-02 AC4): Given a trace profile, when parsed, then phase totals match `bazel analyze-profile` within 1 %.
- **T-0016-AC6** (P4-03 AC1): Given 3 children each touching 512 MiB, when sampled, then the tree's peak footprint is 1.5 GiB + baseline ± 10 %, with ΣRSS reported alongside.
- **T-0016-AC7** (P4-03 AC3): Given 200 pids sampled at 250 ms, then overhead is ≤ 2 % of one core, and swap, swapout and memory-pressure series are written at 1 s.

## Log
- 2026-11-23: Created and dispatched (wave A1).

## Outcome
_Pending._
