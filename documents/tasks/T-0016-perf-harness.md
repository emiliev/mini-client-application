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
- 2026-11-23: Engineer built `tool/perf/` (bench, env, lock, flags, execlog, traceprof, sampler), the genrule test workspace and 28 self-tests. Evidence in `documents/evidence/T-0016/engineer/`.

## Outcome
Status: ready for Verifier. Run `cd tool/perf && python3 -I -m unittest discover -s tests -v` (41 tests, 40 pass, 1 skipped, about 40 s).

| AC | Tests (`tool/perf/tests/`) | Result |
|---|---|---|
| AC1 | `test_ac1_flags.py`: `test_T_0016_AC1_*` (6) | pass. The real run reports `build:verbose_explanations` MISSING on Bazel 9.2.0 (removed upstream), so `bench.py flags` exits 1 by design; `evidence/.../flags.txt` |
| AC2 | `test_ac2_lock.py`: `test_T_0016_AC2_*` (12), process table mocked, incl. a real `ps` output fixture | pass |
| AC3 | `test_ac3_env.py`: `test_T_0016_AC3_*` (4) | pass |
| AC4 | `test_ac4_execlog.py`: `test_T_0016_AC4_*` (8), incl. real Bazel two-log diff (changed: `//:out_a`, `//:out_ab`) and a 50k-spawn, over-50 MiB synthetic log with bounded peak RSS | pass |
| AC5 | `test_ac5_profile.py`: `test_T_0016_AC5_*` (6) | **partial.** Phase totals are exact on a fixture and sanity-checked against BEP, but the reference comparison with `bazel analyze-profile` is **skipped (deferred)**: Bazel 9.2.0 has no such command. A new reference is needed (see follow-ups) |
| AC6 | `test_ac6_ac7_sampler.py`: `test_T_0016_AC6_*` (3, incl. pid-reuse eviction and thread-safe rusage) | pass (tree peak minus baseline within 1.5 GiB +-10 %, ΣRSS reported) |
| AC7 | `test_ac6_ac7_sampler.py`: `test_T_0016_AC7_*` | pass (overhead below 2 % of a core at 200 pids, 250 ms; 1 s swap, swapouts and pressure series) |

**Review and Verifier fixes (second round, squashed into one commit; the bazel-* symlinks and MODULE.bazel.lock are not in any commit):**
1. Symlinks removed, `.gitignore` (`bazel-*`, lock), `copytree(ignore=...)`; test `AC4_workspace_copy_skips_bazel_symlinks_and_none_are_tracked`; suite run from a fresh `git clone` in /tmp passes.
2. `bep_timing`: `*InMs` not scaled, Duration values converted; AC5 real-trace test asserts phase sum within 1 % of BEP wall (measured 0.03 %); unit test `AC5_bep_units_...`.
3. Own server excluded by `--output_base` argv match and `server.pid.txt` (`bench.run_timed(output_base=...)`, `bench.py run --output-base`); tests `AC2_own_output_base_server...`, `AC2_foreign_server_mid_run...`.
4. `strip_separator` drops only the leading `--` (`AC2_run_strips_only_the_leading_separator`).
5. `sampler_cpu_fraction` = sum of `time.thread_time()` of the two sampler threads (`AC7_overhead_counts_sampler_threads_only`).
6. Caches evicted when a pid leaves the table; a changed `ri_proc_start_abstime` resets class and parent (`AC6_exited_pids_are_evicted_and_reused_pid_is_reclassified`).
7. ctypes buffers are per call / thread-local (`AC6_rusage_is_thread_safe`).
8. Spawn key = mnemonic + label + outputs; repeats kept as `key#n` and reported (`AC4_key_collisions_are_kept_and_reported`, `AC4_key_includes_target_label`).
Nits: `bazel_help` raises on a non-zero exit and uses a per-process output base (`AC1_failed_bazel_help...`, `AC1_help_output_base_is_per_process`); finding F-0008 written (index left to the TL).

**AC7 root cause and numbers.** The 2.0 to 2.3 % came from (a) counting RUSAGE_CHILDREN (the `vm_stat` fork, now `host_statistics64` via ctypes) and (b) per-tick cost: rebuilding the whole-table child map, allocating buffers and rounding every row. Now the tree is rebuilt only when the pid table or roots change, buffers are reused per thread, rounding happens at write time. Sampler-thread CPU at 200 pids / 250 ms with 8 busy `yes` processes (load about 9): 1.19 % before, 0.35 % after. `evidence/.../ac7_five_runs_under_load.txt`: 5 of 5 passes at load 8.7 down to 6.1 (before the change: 3 of 5 failed at 2.2 % at load 4.6 to 8.9). Threshold unchanged at 2 %.

**Ingestion approach:** `--execution_log_json_file` (streamed, incremental `raw_decode`; Bazel 9.2 emits concatenated pretty-printed JSON, not NDJSON). Compact-log ingestion is a follow-up: no converter ships with the Homebrew Bazel; `execlog.iter_spawns(converter=[...])` is the hook for a converter built from the pinned source (KD-7).

**Findings and follow-ups for the Tech Lead**
- `--verbose_explanations` and `bazel analyze-profile` do not exist in Bazel 9.2.0: plan 04 §6.3 needs editing, and AC5 needs a new reference (e.g. a Bazel-source `analyze-profile` equivalent, or a pinned golden).
- Bazel allows only one `--execution_log_*_file` per build (the profile U rc has the compact one).
- The calibration run itself (S0 null build, `dart compile kernel`, `gen_snapshot`) and the reference values are not implemented; only the drift check is (needs the S0 app).
- A foreign Bazel server from another worktree was running during the work, so a timed `bench.py run` here would refuse, as designed.
- Not done (deferred ACs): P4-01 AC5, P4-02 AC1, P4-03 AC2.
