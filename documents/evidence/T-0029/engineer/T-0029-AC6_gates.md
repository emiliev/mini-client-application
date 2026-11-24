# T-0029-AC6: gates (Engineer, after merging origin/main 0aab035 and rebasing 0003 onto 0001+0002)

Committed MODULE.bazel (pin + 0001 + 0002 + 0003, 0003 exported from fork commit `9fd728e6`), no `.bazelrc.user`, `--output_base=/tmp/mc-ob-T-0029-engineer`.

```
check ai_rules_dart: 3 patch(es) apply strictly on pin e7163aab8f91
CHECK EXIT 0
Executed 0 out of 51 tests: 51 tests pass.
TEST EXIT 0
Executed 2 out of 2 tests: 2 tests pass.
T0029NOCACHE EXIT 0
LINT EXIT 0
mc_arch_check: OK (/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a5202de903259c057)
ARCH EXIT 0
Formatted 13 files (0 changed) in 0.01 seconds.
REPOFMT EXIT 0
CHECK29 AC1_junit_names EXIT 0
CHECK29 AC2_missing_step EXIT 0
CHECK29 AC3_scaffold EXIT 0
CHECK29 AC4_no_analyzer EXIT 0
CHECK29 AC5_stock_fallback EXIT 1 (duplicate `dio` in the overlay copy after the merge; fixed, re-run: EXIT 0)
CHECK27 AC1 EXIT 0
CHECK28 AC1 EXIT 0
```

`test --lockfile_mode=error //...`: 51 tests pass (cache hits); the T-0029 targets (`//spike/bdd_sample:bdd_test`, `//utility/mc_test_steps:data_table_test`) were also run with `--nocache_test_results`. T-0027-AC1 and T-0028-AC1 report every retrofit and injectable output EQUAL to build_runner's after the joint ext-lock resolve.

## Fork, its own workspace (`bazelisk test --lockfile_mode=update --nocache_test_results //dart/ext/bdd:all` at `9fd728e6`)
```
//dart/ext/bdd:bdd_generator_test                                        PASSED in 0.4s
Executed 1 out of 1 test: 1 test passes.
EXIT 0
$ dart format --output=none --set-exit-if-changed dart/ext/bdd (fork SDK 3.13.5)
Formatted 4 files (0 changed) in 0.01 seconds.
exit 0
```

**PASS T-0029-AC6**
