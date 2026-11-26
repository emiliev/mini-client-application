# T-0042-AC5: gates on the synced tree (23 synced files)

| Gate | Result |
|---|---|
| tool/ide_sync --env dev (the gates run on the synced tree) | PASS |
| test //... (synced tree) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| ide_sync script tests (T-0042-AC5) | PASS |
| T-0032-AC6 byte-identity with build_runner (synced tree) | PASS |

- tests: Executed 0 out of 101 tests: 101 tests pass.

**PASS T-0042-AC5-gates**
