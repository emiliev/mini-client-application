# T-0058-AC5: layering

## T-0044-AC4 layering (mc_ds_inputs, mc_ds_navigation, mc_arch_check): PASS
## closure of //utility/mc_ds_overlays:mc_ds_overlays //utility/mc_ds_overlays:overlays_test //utility/mc_ds_overlays:golden_test
```
forbidden in closure: none
```
## pubspec, BUILD, lib and test name a forbidden package (comments aside)
```
none
```
## positive control: characters_list closure holds mc_feature_flow (5 targets) and mc_paging (8 targets)
## negative controls (each must be reported)
```
mc_feature_flow BUILD dep (closure):   //utility/mc_ds_overlays:mc_ds_overlays -> //utility/mc_feature_flow:lib/mc_feature_flow.dart //utility/mc_feature_flow:lib/src/feature_flow.dart //utility/mc_feature_flow:lib/src/flow_context.dart //utility/mc_feature_flow:lib/testing.dart 
mc_feature_flow pubspec dep:         utility/mc_ds_overlays/pubspec.yaml:16:  mc_feature_flow: any
mc_feature_flow lib import:          utility/mc_ds_overlays/lib/src/mc_dialog.dart:1:import 'package:mc_feature_flow/mc_feature_flow.dart';
mc_feature_flow import + trailing ///: utility/mc_ds_overlays/lib/src/mc_dialog.dart:1:import 'package:mc_feature_flow/mc_feature_flow.dart'; /// layering
mc_feature_flow test import:         utility/mc_ds_overlays/test/overlays_test.dart:1:import 'package:mc_feature_flow/mc_feature_flow.dart';
mc_paging BUILD dep (closure):   //utility/mc_ds_overlays:mc_ds_overlays -> //utility/mc_paging:_paged_state_freezed //utility/mc_paging:lib/mc_paging.dart //utility/mc_paging:lib/src/page.dart //utility/mc_paging:lib/src/paged_state.dart 
mc_paging pubspec dep:         utility/mc_ds_overlays/pubspec.yaml:16:  mc_paging: any
mc_paging lib import:          utility/mc_ds_overlays/lib/src/mc_dialog.dart:1:import 'package:mc_paging/mc_paging.dart';
mc_paging import + trailing ///: utility/mc_ds_overlays/lib/src/mc_dialog.dart:1:import 'package:mc_paging/mc_paging.dart'; /// layering
mc_paging test import:         utility/mc_ds_overlays/test/overlays_test.dart:1:import 'package:mc_paging/mc_paging.dart';
```

**PASS T-0058-AC5-layering**
