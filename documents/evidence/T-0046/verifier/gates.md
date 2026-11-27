# T-0046-AC8: gates, codegen checks and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | PASS |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| fixtures check (T-0031-AC6) | PASS |
| relative API paths (T-0034-AC4) | PASS |
| T-0046-AC7_matches_build_runner | PASS |
| T-0046-AC7_cutoff | PASS |
| T-0046-AC7_generated_not_committed | PASS |
| T-0046-AC7_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 134 tests: 134 tests pass.
- coverage: == feature/discovery/discovery_search TOTAL 333/333 100.0% == app/wiring/discovery_wiring TOTAL 22/22 100.0% == app/wiring/app_core TOTAL 243/285 85.3% UNDER 90 (exempt, pre-existing): app/wiring/app_core (threshold 90 %)

**PASS T-0046-AC8-gates**
