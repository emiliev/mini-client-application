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
| coverage >= 90 % (touched packages) | **FAIL** |

- tests: Executed 1 out of 214 tests: 214 tests pass.
- coverage: == feature/settings/settings_appearance TOTAL 235/236 99.6% == app/wiring/account_wiring TOTAL 23/23 100.0% == app/wiring/app_core TOTAL 512/527 97.2% == utility/mc_appearance TOTAL 338/341 99.1% == utility/mc_storage TOTAL 53/61 86.9% UNDER 90: utility/mc_storage == utility/mc_ds_theme TOTAL 51/55 92.7% (threshold 90 %)

### coverage >= 90 % (touched packages) failed

```
package:app_core/src/sandbox/stub_page.dart: 6/6 100.0% missed=[]
package:app_core/src/shell/app_appearance.dart: 9/9 100.0% missed=[]
package:app_core/src/shell/error_hooks.dart: 16/18 88.9% missed=[9, 10]
package:app_core/src/shell/mc_app.dart: 76/81 93.8% missed=[133, 134, 206, 231, 237]
package:app_core/src/shell/route_probe.dart: 19/19 100.0% missed=[]
package:app_core/src/sign_in/fixture_sign_in_sheet.dart: 53/53 100.0% missed=[]
TOTAL 512/527 97.2%
== utility/mc_appearance
package:mc_appearance/src/appearance.dart: 184/184 100.0% missed=[]
package:mc_appearance/src/appearance_di_initializer.dart: 16/18 88.9% missed=[32, 33]
package:mc_appearance/src/appearance_preferences.dart: 56/56 100.0% missed=[]
package:mc_appearance/src/appearance_snapshot.dart: 12/12 100.0% missed=[]
package:mc_appearance/src/appearance_store.dart: 39/39 100.0% missed=[]
package:mc_appearance/src/preferences_api.dart: 31/32 96.9% missed=[96]
TOTAL 338/341 99.1%
== utility/mc_storage
package:mc_storage/src/file_store.dart: 53/57 93.0% missed=[13, 14, 142, 143]
package:mc_storage/src/storage_di_initializer.dart: 0/4 0.0% missed=[10, 12, 13, 14]
TOTAL 53/61 86.9%
UNDER 90: utility/mc_storage
== utility/mc_ds_theme
package:mc_ds_theme/src/mc_theme.dart: 40/40 100.0% missed=[]
package:mc_ds_theme/src/mc_theme_extension.dart: 9/13 69.2% missed=[13, 15, 16, 17]
package:mc_ds_theme/src/theme_mode_controller.dart: 2/2 100.0% missed=[]
TOTAL 51/55 92.7%
```

**FAIL T-0063-AC7-gates**
