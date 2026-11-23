# tool/perf: perf harness foundations (T-0016)

Python 3.9 stdlib only, no pip. Run every script as `python3 -I`. Plan: `documents/plan/04-profiling-optimization-upstream.md`.

| File | Purpose |
|---|---|
| `bench.py` | `flags` (AC1 inventory, exit 1 and names missing flags), `env`, `run --out DIR -- CMD` (timed-run skeleton: lock, env.json, contamination polling) |
| `flags.py` | Flags from `profiles/*.bazelrc` plus plan 04 §6.3, checked against `bazel help <topic> --long` |
| `env.py` | `env.json` capture, `machine_drift` (> 5 %) |
| `lock.py` | `/tmp/mc-perf.lock` (flock), foreign Bazel server / `launchd_sim` detection, mid-run contamination. Read-only on the process table: it never boots or kills anything |
| `execlog.py` | Streaming execution-log ingestion and 1:1 spawn diff by input digest |
| `traceprof.py` | Trace-profile phase totals, BEP timing |
| `sampler.py` | Process-tree sampler: Σ`phys_footprint` (KD-2), ΣRSS, per-class peaks, 1 s swap / swapouts / pressure series |
| `classes.json` | argv class table (versioned with `bench_version`) |
| `testdata/genrule_ws/` | Genrule-only Bazel workspace for real logs |

## Tests
```
cd tool/perf && python3 -I -m unittest discover -s tests -v
```
Tests that run Bazel use a copy of `testdata/genrule_ws` with `--output_base` under `/tmp` and run `bazel shutdown` on cleanup. Test names carry the AC ID. The AC6 test allocates 1.5 GiB for about 4 s; the AC7 test spawns 200 `sleep` processes.

## Execution-log ingestion: what is and is not done
- **Done:** `--execution_log_json_file`. Bazel 9.2 writes *concatenated pretty-printed* JSON objects (not newline-delimited), so `execlog.iter_json_objects` is an incremental `raw_decode` reader. Per spawn only a small record is kept, nothing is sorted. KD-7 allows JSON at S0-S1 only.
- **Follow-up:** the compact log (`--execution_log_compact_file`, zstd protobuf). The Homebrew Bazel 9.2 install has no converter binary. Build Bazel's `//src/tools/execlog:converter` from the pinned source tag, then run `execlog.py --converter /path/to/converter --input_path ...`: `iter_spawns(converter=[...])` streams the converter's stdout into the same reader. Note that the converter's flags must be confirmed against the tag.
- Other Bazel 9.2 facts: `--execution_log_*` flags are mutually exclusive (one per build); `bazel analyze-profile` no longer exists; `--verbose_explanations` no longer exists (so `bench.py flags` currently exits 1 naming it; `--explain` alone remains). A missing flag in plan 04 §6.3 needs a plan edit by the Tech Lead.

## Sampler notes
No forks per sample: `proc_listallpids`, `proc_pidinfo` (parent pid, cached), `proc_pid_rusage(RUSAGE_INFO_V4)` and `host_statistics64` (swapouts) through ctypes; `sysctl` for `vm.swapusage`, pressure level and `KERN_PROCARGS2`. `ps` / `vm_stat` are fallbacks (`ps_fallback` has no footprint). Processes living under 0.5 s can be missed (plan 04 §6.4).
