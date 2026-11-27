# T-0058-AC5: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| flow_builder provenance (evergreen) | PASS |
| fixtures closure (T-0031-AC6, covers mc_ds_overlays) | PASS |
| no direct overlay calls (T-0058-AC4) | PASS |
| layering (T-0058-AC5, re-runs T-0044-AC4 and T-0040-AC3) | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 23 out of 181 tests: 181 tests pass.
- coverage: == utility/mc_ds_overlays TOTAL 220/222 99.1% (threshold 90 %)

**PASS T-0058-AC5-gates**
