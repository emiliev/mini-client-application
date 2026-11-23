# F-0008: Bazel 9.2.0 tooling gaps that affect the perf harness

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0016)
- **Type:** Tool behaviour
- **Related:** T-0016, plan 04 §6.3, KD-7, R21

## Summary
Four behaviours of the installed Homebrew Bazel 9.2.0 differ from what plan 04 assumes:
1. **`bazel analyze-profile` does not exist** (`Command 'analyze-profile' not found`). T-0016-AC5's reference comparison cannot run. The harness derives phase totals itself from the trace's `build phase marker` events; on real builds the phase sum matches BEP `wallTimeInMs` within about 0.03 %. A new reference (Bazel's source-built analyzer, or BEP) is a TL decision.
2. **`--verbose_explanations` does not exist.** Only `--explain=<file>` remains. `bench.py flags` therefore exits 1 naming `build:verbose_explanations` until plan 04 §6.3 drops it.
3. **`--execution_log_json_file` writes concatenated, pretty-printed JSON objects, not newline-delimited JSON.** Any reader must decode incrementally (`json.JSONDecoder.raw_decode` over a buffer). A line-based reader finds nothing usable. A build with zero executed spawns writes an empty file.
4. **Only one of `--execution_log_binary_file`, `--execution_log_json_file` and `--execution_log_compact_file` is allowed per build.** Passing two fails the build at the start. Also, the Homebrew install has no execlog converter, so compact logs need one built from the pinned source (KD-7).

Related BEP fact: `timingMetrics` fields named `*InMs` are int64 strings already in milliseconds, while `criticalPathTime` is a Duration string (`"0.043s"`).

## Evidence
`tool/perf/tests/test_ac4_execlog.py`, `test_ac5_profile.py`, `documents/evidence/T-0016/engineer/flags.txt`. Three real builds: phase sums 10479.2, 14037.7 and 11220.2 ms against `wallTimeInMs` 10481, 14040 and 11222.

## Implications / actions
- TL: edit plan 04 §6.3 (drop `--verbose_explanations`, replace `analyze-profile`), decide the AC5 reference, and schedule the converter build.
- Harness code: use `execlog.iter_json_objects` for any JSON exec log.
