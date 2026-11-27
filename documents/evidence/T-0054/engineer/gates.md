# T-0054-AC5: gates and coverage

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
| flow_builder provenance (T-0035-AC4) | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 0 out of 167 tests: 167 tests pass.
- coverage: == app/mini_client TOTAL 128/133 96.2% == app/wiring/app_core TOTAL 463/478 96.9% == app/wiring/library_wiring TOTAL 39/39 100.0% == app/wiring/publishing_wiring TOTAL 47/47 100.0% == app/wiring/universe_wiring TOTAL 39/39 100.0% == app/wiring/discovery_wiring TOTAL 22/22 100.0% (threshold 90 %)

**PASS T-0054-AC5-gates**
