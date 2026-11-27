# T-0059-AC5: layering

## mc_arch_check: PASS
```
INFO: Build completed successfully, 1 total action
INFO: Running command line: bazel-bin/tool/mc_arch_check/bin
mc_arch_check: OK (/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a773738fafc5123b2)
```
## closure of the library
```
unexpected in closure: none
```
## pubspec, BUILD and Dart files name a package outside the allowed set
```
none
```
## lower DS packages naming mc_ds_charts
```
none
```
## positive control: the library closure holds mc_ds_feedback (5 targets) and mc_ds_buttons (4 targets)
## positive control: characters_list closure holds mc_paging (8 targets), which the allowed set does not
## positive control: the scan flags characters_list
```
//feature/characters/characters_list:characters_list -> feature/characters/characters_list utility/mc_api_client utility/mc_api_errors utility/mc_bloc_kit utility/mc_config utility/mc_di 
```
## negative controls (each must be reported)
```
mc_paging BUILD dep (closure):   //utility/mc_ds_charts:mc_ds_charts -> utility/mc_api_errors utility/mc_di utility/mc_paging utility/mc_prelude utility/mc_storage 
mc_paging BUILD dep (scan):      BUILD:16:mc_paging
mc_paging pubspec dep:         pubspec:16:mc_paging
mc_paging lib import:          utility/mc_ds_charts/lib/src/chart_common.dart:1:mc_paging
mc_paging import + trailing ///: utility/mc_ds_charts/lib/src/chart_common.dart:1:mc_paging
mc_paging test import:         utility/mc_ds_charts/test/charts_test.dart:1:mc_paging
mc_feature_flow BUILD dep (closure):   //utility/mc_ds_charts:mc_ds_charts -> utility/mc_bloc_kit utility/mc_di utility/mc_feature_flow utility/mc_l10n_core utility/mc_monitoring 
mc_feature_flow BUILD dep (scan):      BUILD:16:mc_feature_flow
mc_feature_flow pubspec dep:         pubspec:16:mc_feature_flow
mc_feature_flow lib import:          utility/mc_ds_charts/lib/src/chart_common.dart:1:mc_feature_flow
mc_feature_flow import + trailing ///: utility/mc_ds_charts/lib/src/chart_common.dart:1:mc_feature_flow
mc_feature_flow test import:         utility/mc_ds_charts/test/charts_test.dart:1:mc_feature_flow
mc_ds_inputs BUILD dep (closure):   //utility/mc_ds_charts:mc_ds_charts -> utility/mc_ds_inputs 
mc_ds_inputs BUILD dep (scan):      BUILD:16:mc_ds_inputs
mc_ds_inputs pubspec dep:         pubspec:16:mc_ds_inputs
mc_ds_inputs lib import:          utility/mc_ds_charts/lib/src/chart_common.dart:1:mc_ds_inputs
mc_ds_inputs import + trailing ///: utility/mc_ds_charts/lib/src/chart_common.dart:1:mc_ds_inputs
mc_ds_inputs test import:         utility/mc_ds_charts/test/charts_test.dart:1:mc_ds_inputs
mc_ds_layout -> mc_ds_charts (cycle): utility/mc_ds_layout/pubspec.yaml:12:  mc_ds_charts: any
```

**PASS T-0059-AC5-layering**
