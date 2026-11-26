# T-0039-AC5: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| closure: the three packages are pure Dart | PASS |
| fixtures check (T-0031-AC6) | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 101 tests: 101 tests pass.
- coverage: == utility/mc_session TOTAL 92/92 100.0% == utility/mc_api_auth TOTAL 119/119 100.0% == utility/mc_fixtures_identity TOTAL 128/130 98.5% (threshold 90 %)

**PASS T-0039-AC5-gates**
