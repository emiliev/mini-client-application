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
| coverage >= 90 % (touched packages) | **FAIL** |

- tests: Executed 0 out of 134 tests: 134 tests pass.
- coverage: == feature/discovery/discovery_search TOTAL 294/294 100.0% == app/wiring/discovery_wiring TOTAL 22/22 100.0% == app/wiring/app_core TOTAL 243/285 85.3% UNDER 90: app/wiring/app_core (threshold 90 %)

### coverage >= 90 % (touched packages) failed

```
== app/wiring/discovery_wiring
package:discovery_wiring/discovery_wiring.dart: 1/1 100.0% missed=[]
package:discovery_wiring/src/di/di_initializer.dart: 3/3 100.0% missed=[]
package:discovery_wiring/src/di/discovery_wiring_di_initializer.dart: 6/6 100.0% missed=[]
package:discovery_wiring/src/navigators/discovery_search_navigator_impl.dart: 5/5 100.0% missed=[]
package:discovery_wiring/src/routes/route_targets_impl.dart: 3/3 100.0% missed=[]
package:discovery_wiring/src/routes/search_routes.dart: 4/4 100.0% missed=[]
TOTAL 22/22 100.0%
== app/wiring/app_core
package:app_core/src/boot/boot_bloc.dart: 49/50 98.0% missed=[106]
package:app_core/src/boot/boot_page.dart: 17/17 100.0% missed=[]
package:app_core/src/boot/boot_state.dart: 5/5 100.0% missed=[]
package:app_core/src/di/mocked_backend_di_initializer.dart: 23/27 85.2% missed=[29, 37, 38, 78]
package:app_core/src/di/root_initializers.dart: 12/13 92.3% missed=[46]
package:app_core/src/links/e2e_start_link.dart: 7/8 87.5% missed=[24]
package:app_core/src/links/pending_links.dart: 41/42 97.6% missed=[69]
package:app_core/src/locations/app_locations.dart: 4/6 66.7% missed=[18, 22]
package:app_core/src/media/app_media.dart: 0/1 0.0% missed=[22]
package:app_core/src/router/router_ref.dart: 10/10 100.0% missed=[]
package:app_core/src/sandbox/stub_page.dart: 0/6 0.0% missed=[6, 10, 11, 13, 14, 16]
package:app_core/src/shell/error_hooks.dart: 16/18 88.9% missed=[9, 10]
package:app_core/src/shell/mc_app.dart: 59/63 93.7% missed=[105, 106, 155, 172]
package:app_core/src/shell/route_probe.dart: 0/19 0.0% missed=[14, 17, 21, 23, 24, 25, 30, 31, 33, 34, 39, 40, 42, 43, 47, 48, 53, 61, 63]
TOTAL 243/285 85.3%
UNDER 90: app/wiring/app_core
```

**FAIL T-0046-AC8-gates**
