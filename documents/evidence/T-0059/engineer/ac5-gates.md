# T-0059-AC5: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| flow_builder provenance (evergreen) | PASS |
| fixtures closure (T-0031-AC6, covers mc_ds_charts) | PASS |
| layering (T-0059-AC5) | PASS |
| no existing golden changed (vs origin/main) | PASS |
| no suppressions or skips in the package | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 73 out of 182 tests: 182 tests pass.
- coverage: == utility/mc_ds_charts TOTAL 982/991 99.1% (threshold 90 %)

**PASS T-0059-AC5-gates**
