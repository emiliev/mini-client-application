# T-0048-AC8: gates, codegen checks and coverage

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
| T-0048-AC7_matches_build_runner | PASS |
| T-0048-AC7_cutoff | PASS |
| T-0048-AC7_generated_not_committed | PASS |
| T-0048-AC7_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | **FAIL** |

- tests: Executed 3 out of 136 tests: 136 tests pass.
- coverage: == feature/library/library_reading_list_editor TOTAL 768/788 97.5% == app/wiring/library_wiring TOTAL 37/37 100.0% == app/wiring/app_core TOTAL 311/353 88.1% UNDER 90: app/wiring/app_core == app/wiring/publishing_wiring TOTAL 47/47 100.0% (threshold 90 %)

### coverage >= 90 % (touched packages) failed

```
package:app_core/src/di/mocked_backend_di_initializer.dart: 23/27 85.2% missed=[29, 37, 38, 78]
package:app_core/src/di/root_initializers.dart: 12/13 92.3% missed=[46]
package:app_core/src/links/e2e_start_link.dart: 7/8 87.5% missed=[24]
package:app_core/src/links/pending_links.dart: 41/42 97.6% missed=[69]
package:app_core/src/locations/app_locations.dart: 3/5 60.0% missed=[18, 22]
package:app_core/src/media/app_media.dart: 0/1 0.0% missed=[22]
package:app_core/src/router/flow_results.dart: 14/14 100.0% missed=[]
package:app_core/src/router/router_ref.dart: 10/10 100.0% missed=[]
package:app_core/src/sandbox/stub_page.dart: 0/6 0.0% missed=[6, 10, 11, 13, 14, 16]
package:app_core/src/shell/error_hooks.dart: 16/18 88.9% missed=[9, 10]
package:app_core/src/shell/mc_app.dart: 59/63 93.7% missed=[105, 106, 155, 172]
package:app_core/src/shell/route_probe.dart: 0/19 0.0% missed=[14, 17, 21, 23, 24, 25, 30, 31, 33, 34, 39, 40, 42, 43, 47, 48, 53, 61, 63]
package:app_core/src/sign_in/fixture_sign_in_sheet.dart: 55/55 100.0% missed=[]
TOTAL 311/353 88.1%
UNDER 90: app/wiring/app_core
== app/wiring/publishing_wiring
package:publishing_wiring/publishing_wiring.dart: 3/3 100.0% missed=[]
package:publishing_wiring/src/di/di_initializer.dart: 3/3 100.0% missed=[]
package:publishing_wiring/src/di/publishing_wiring_di_initializer.dart: 6/6 100.0% missed=[]
package:publishing_wiring/src/flows/creator_details_placeholder_flow.dart: 11/11 100.0% missed=[]
package:publishing_wiring/src/navigators/comics_details_navigator_impl.dart: 11/11 100.0% missed=[]
package:publishing_wiring/src/routes/comics_routes.dart: 4/4 100.0% missed=[]
package:publishing_wiring/src/routes/creators_routes.dart: 4/4 100.0% missed=[]
package:publishing_wiring/src/routes/route_targets_impl.dart: 5/5 100.0% missed=[]
TOTAL 47/47 100.0%
```

**FAIL T-0048-AC8-gates**
