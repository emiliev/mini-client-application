# Verification report — T-0016: Perf harness foundations (re-verification)

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-23
- **Branch / commit verified:** `fleet/T-0016-perf-harness` rebuilt as `470faad` (single commit on `daf3b70`); verification branch `fleet/T-0016-verify2`
- **Simulator:** none used (tooling task)
- **Verdict:** PASS
- **History:** the first round (f4e3452) was FAIL (AC5, AC7, dangling symlinks). Each finding is updated below.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Symlinks / lock not committed | `git log --stat daf3b70..470faad`, `git ls-files` | no `bazel-*` symlink and no `MODULE.bazel.lock` in any commit (single commit, 31 files) |
| Suite from a fresh clone | `git clone` to `/tmp`, checkout `470faad`, `cd tool/perf && python3 -I -m unittest discover -s tests -v` | 41 run, OK, 1 skipped (`analyze-profile` reference, obsolete by the AC5 amendment), about 40 s |
| AC7 under load, 5 runs | `-k AC7_200`, 6 busy-loop processes added, load average 3.5 to 8.9 | 5 of 5 OK (plus 3 of 3 OK in an earlier pass; also OK inside the full suite at load average 13) |
| Third-party imports | grep | none; `python3 -I` used |
| Bazel servers | `ps` | the tests shut down their own servers; none of mine remain |

## Acceptance criteria
| AC | Mapped test(s) | Test really asserts the AC? | Result |
|---|---|---|---|
| T-0016-AC1 | `test_ac1_flags` (6) | yes; new tests: failed `bazel help` raises (no false "all missing"), per-process output base | PASS |
| T-0016-AC2 | `test_ac2_lock` (11) | yes; flock refusal, foreign server, simulator, load, mid-run intruder only marks `contaminated`. New: own output-base exclusion, mid-run foreign server still contaminates, leading `--` only, and `parses_real_ps_output_fixture` feeds real `ps` text through the parser (closes my earlier low finding) | PASS |
| T-0016-AC3 | `test_ac3_env` (4) | yes | PASS |
| T-0016-AC4 | `test_ac4_execlog` (8) | yes; real two-log Bazel diff, bounded RSS on a 50k-spawn, 50 MiB+ log (earlier independent run: 197 MB log at 120 MB RSS). Spawn key now includes the target label and collisions are kept and reported (earlier low finding fixed). `workspace_copy_skips_bazel_symlinks_and_none_are_tracked` guards the symlink defect | PASS |
| T-0016-AC5 (as amended) | `test_ac5_profile` (5 run, 1 skipped) | yes now: fixture totals exact, and the real-trace test asserts `abs(sum(phases) - wallTimeInMs) / wall < 0.01`. `bep_timing` no longer scales `*InMs` fields (unit test `bep_units_...`; Duration strings convert). My earlier manual run: 584.0 vs 585 ms | PASS |
| T-0016-AC6 | `test_ac6_ac7_sampler` | yes; reads `ri_phys_footprint` via `proc_pid_rusage` (round 1: 1 GiB child, sampler 1028.7 MiB vs `footprint` 1029 MB). New: thread-safe per-thread buffers, exited-pid eviction with reused pid reclassified | PASS |
| T-0016-AC7 | `test_ac6_ac7_sampler` | yes; threshold still 2 %. The CPU measure now counts only the two sampler threads (`time.thread_time`) rather than the whole process plus children. Not weakened in value: it is a more accurate definition of "sampler overhead" | PASS |

## Review fixes checked
- Own-server exclusion by output base: tests above, plus a mid-run foreign server still contaminating. OK.
- Leading `--` only is stripped (`cmd[1:] if cmd[0]=="--"`). OK.
- Per-thread ctypes buffers (`threading.local`). OK.
- Pid-reuse eviction in the sampler. OK.
- Spawn-key collisions kept and reported. OK.
- F-0008 exists and is accurate (analyze-profile and `--verbose_explanations` absent, one exec log flag per build, pretty-printed JSON, BEP units).

## Test-integrity audit
- Tests deleted, skipped or weakened: one skip (`AC5_matches_bazel_analyze_profile_within_1_percent`, disclosed, no such Bazel command). AC7 changed its overhead definition (sampler threads only), threshold unchanged at 2 %. Nothing else.
- Lint suppressions: `# noqa: E402/F401` on imports only.
- Golden files updated: none.

## Issues found
1. (Low, new) The sampler timestamps use `time.time()`; when the machine sleeps mid-run the series shows a huge gap. One of my runs hit a 699 s suspend and failed the 1 s cadence check (environmental, not a code fault; the next run passed). Consider `time.monotonic()`, noting that sleep still stalls a run.
2. (Info) AC7's margin under heavy load was not directly reported; the test only prints the fraction on failure.
3. Resolved from round 1: dangling symlinks, AC5 1 % assertion and BEP units, AC7 overhead, `ps` parsing test, duplicate spawn keys.

## Notes for the Tech Lead
- Safe to merge `470faad` from `fleet/T-0016-perf-harness`; do not merge `fleet/T-0016-verify` (old history).
- Deferred ACs (P4-01 AC5, P4-02 AC1, P4-03 AC2) remain for a task with the S0 app.
