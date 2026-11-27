# T-0057 Verification report

- **Verifier:** fresh Sonnet-tier Verifier, did not write the code.
- **Commit verified:** `5e3956f` (detached).
- **Verdict:** **PASS.** No defects.

| Check | Result |
|---|---|
| Test-only | `git diff origin/main...5e3956f --stat`: the test file, `tool/checks/T-0057-AC2_mutations.sh`, the F-0049 note, the task file and engineer evidence. Nothing under `lib/`. |
| Faithful probes (AC1) | The 4 `T-0057-AC1` tests match VP07b (400 ms guard, 100+100 ms pumps, empty before the redirect ends, tap, `c:null`), VP16 (async guard, push then `go('/other')`, `c:null`, no sign-in page) and VP23 (`replace` and `pushReplacement`, `e:null` only after Back, `c:l-5` after finish). Each asserts exact completions (once, expected value) and no leftover `debugOnChange` listener (a `go` away and back, count unchanged). VP23 adds a `takeException` is null check. |
| `_app` helper changes | The diff only adds: `tagged`, `create`/`edit`, the optional `guardDelay` and the `/other` route. With `guardDelay == null` the redirect returns exactly what it did before. No existing T-0054 test is touched or weakened. |
| Mutations by hand (AC2) | Applied with my own sed script (restore with `git checkout`, tree clean afterwards). The unmutated baseline passes with both test files. See the table below. |
| Script | Read: it refuses a dirty tree (exit 2) and sets the trap before the first edit (the baseline run and every edit come after it). It counts a build failure as BROKEN. The CONTROL `TIMEOUT` branch is a failure, not a survival. A failed `cut_group` would leave the group in place, so the control would be KILLED and flagged (safe). |
| Flake check | `--runs_per_test=50 --nocache_test_results`: PASSED, 50 runs, 0 failures (max 4.3 s). |
| Gates | `test --lockfile_mode=error //...`: 178 of 178 pass. `build --config=lint //...`: OK. `dart format` on the test file: 0 changes. |

## Mutations

| Mutant | At HEAD (suite as committed) | With `origin/main` test file (control) |
|---|---|---|
| X02 always superseded | KILLED by `T-0057-AC1 a slow async guard...` | PASSED (survives) |
| X03 never superseded | KILLED by `T-0057-AC1 an async guard and a go in the same span...` | PASSED (survives) |
| X06 match any pushed page | KILLED by `T-0057-AC1 ... replace` and `... pushReplacement` | PASSED (survives) |

## Not run
The engineer's mutation script itself (the task asked for hand-applied mutations), and `mc_arch_check` separately (the `//...` run covers whatever targets exist).
