# T-0040-AC4: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| flow_builder provenance (evergreen) | PASS |
| fixtures closure (T-0031-AC6, covers mc_ds_navigation) | PASS |
| layering (T-0040-AC3) | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 5 out of 87 tests: 87 tests pass.
- coverage: == utility/mc_ds_navigation TOTAL 109/109 100.0% == utility/mc_feature_flow TOTAL 165/166 99.4% == feature/characters/characters_list TOTAL 155/155 100.0% (threshold 90 %)

**PASS T-0040-AC4-gates**
