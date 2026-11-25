# T-0035-AC4: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| flow_builder provenance (evergreen) | PASS |
| lock delta vs 6e7eaaf (one-off, pre-merge) | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 5 out of 79 tests: 79 tests pass.
- coverage: == utility/mc_feature_flow TOTAL 142/143 99.3% == feature/characters/characters_list TOTAL 156/156 100.0% (threshold 90 %)

**PASS T-0035-AC4-gates**
