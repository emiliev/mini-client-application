# T-0044-AC4: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| flow_builder provenance (evergreen) | PASS |
| fixtures closure (T-0031-AC6, covers mc_ds_inputs) | PASS |
| layering (T-0044-AC4, re-runs T-0040-AC3) | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 117 tests: 117 tests pass.
- coverage: == utility/mc_ds_inputs TOTAL 325/340 95.6% == utility/mc_ds_navigation TOTAL 173/186 93.0% (threshold 90 %)

**PASS T-0044-AC4-gates**
