# T-0063-AC7: gates, codegen checks and coverage

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
| T-0063-AC7_matches_build_runner | PASS |
| T-0063-AC7_cutoff | PASS |
| T-0063-AC7_generated_not_committed | PASS |
| T-0063-AC7_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 39 out of 214 tests: 214 tests pass.
- coverage: == feature/settings/settings_appearance TOTAL 265/267 99.3% == app/wiring/account_wiring TOTAL 23/23 100.0% == app/wiring/app_core TOTAL 513/528 97.2% == utility/mc_appearance TOTAL 348/351 99.1% == utility/mc_storage TOTAL 61/61 100.0% == utility/mc_ds_theme TOTAL 51/55 92.7% (threshold 90 %)

**PASS T-0063-AC7-gates**
