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

- tests: Executed 40 out of 137 tests: 137 tests pass.
- coverage: == feature/library/library_reading_list_editor TOTAL 723/736 98.2% == app/wiring/library_wiring TOTAL 37/37 100.0% == app/wiring/app_core TOTAL 354/368 96.2% == app/wiring/publishing_wiring TOTAL 47/47 100.0% == utility/mc_forms TOTAL 286/286 100.0% == utility/mc_api_errors TOTAL 51/60 85.0% UNDER 90: utility/mc_api_errors == utility/mc_fixtures_library TOTAL 203/206 98.5% (threshold 90 %)

### coverage >= 90 % (touched packages) failed

```
package:publishing_wiring/src/navigators/comics_details_navigator_impl.dart: 11/11 100.0% missed=[]
package:publishing_wiring/src/routes/comics_routes.dart: 4/4 100.0% missed=[]
package:publishing_wiring/src/routes/creators_routes.dart: 4/4 100.0% missed=[]
package:publishing_wiring/src/routes/route_targets_impl.dart: 5/5 100.0% missed=[]
TOTAL 47/47 100.0%
== utility/mc_forms
package:mc_forms/src/field_error.dart: 10/10 100.0% missed=[]
package:mc_forms/src/field_spec.dart: 6/6 100.0% missed=[]
package:mc_forms/src/field_state.dart: 25/25 100.0% missed=[]
package:mc_forms/src/form_controller.dart: 101/101 100.0% missed=[]
package:mc_forms/src/form_state.dart: 28/28 100.0% missed=[]
package:mc_forms/src/form_values.dart: 7/7 100.0% missed=[]
package:mc_forms/src/validators.dart: 39/39 100.0% missed=[]
package:mc_forms/src/wizard_controller.dart: 70/70 100.0% missed=[]
TOTAL 286/286 100.0%
== utility/mc_api_errors
package:mc_api_errors/src/api_failure.dart: 51/60 85.0% missed=[22, 64, 66, 68, 74, 77, 78, 106, 107]
TOTAL 51/60 85.0%
UNDER 90: utility/mc_api_errors
== utility/mc_fixtures_library
package:mc_fixtures_library/src/data/reading_list.dart: 9/9 100.0% missed=[]
package:mc_fixtures_library/src/domain.dart: 34/37 91.9% missed=[42, 74, 93]
package:mc_fixtures_library/src/fixture_sets.dart: 3/3 100.0% missed=[]
package:mc_fixtures_library/src/handlers/library_handlers.dart: 157/157 100.0% missed=[]
TOTAL 203/206 98.5%
```

**FAIL T-0048-AC8-gates**
