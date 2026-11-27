# T-0056-AC8: gates, codegen checks and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | **FAIL** |
| build --config=lint //... | **FAIL** |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | **FAIL** |
| l10n_check | PASS |
| fixtures check (T-0031-AC6) | PASS |
| relative API paths (T-0034-AC4) | PASS |
| T-0056-AC8_matches_build_runner | PASS |
| T-0056-AC8_cutoff | PASS |
| T-0056-AC8_generated_not_committed | PASS |
| T-0056-AC8_gen_l10n_parity | PASS |
| coverage >= 90 % (touched packages) | **FAIL** |

- tests: Executed 7 out of 62 tests: 7 tests pass and 55 were skipped.
- coverage: == feature/store/store_home TOTAL 867/882 98.3% == app/wiring/commerce_wiring TOTAL 54/54 100.0% == app/wiring/app_core TOTAL 484/502 96.4% == utility/mc_analytics TOTAL 319/319 100.0% == utility/mc_feature_flow TOTAL 168/169 99.4% == utility/mc_monitoring TOTAL 22/30 73.3% UNDER 90: utility/mc_monitoring == utility/mc_formatters TOTAL 33/33 100.0% (threshold 90 %)

### test //... (touched packages uncached) failed

```
//utility/mc_feature_flow:flow_navigation_channel_test                NO STATUS
//utility/mc_formatters:formatters_di_initializer_test                NO STATUS
//utility/mc_formatters:formatters_test                               NO STATUS
//utility/mc_monitoring:monitoring_test                               NO STATUS
//utility/mc_monitoring:no_flutter_test                               NO STATUS
//utility/mc_test_steps:analytics_steps_test                          NO STATUS
//utility/mc_test_steps:data_table_test                               NO STATUS
//utility/mc_test_steps:flag_steps_test                               NO STATUS
//utility/mc_test_utils:auth_container_test                           NO STATUS
//utility/mc_test_utils:flags_container_test                          NO STATUS
//utility/mc_test_utils:fonts_test                                    NO STATUS
//utility/mc_test_utils:formatters_container_test                     NO STATUS
//utility/mc_test_utils:golden_test                                   NO STATUS
//utility/mc_test_utils:harness_test                                  NO STATUS
//utility/mc_test_utils:init_flow_test                                NO STATUS
//utility/mc_test_utils:isolation_test                                NO STATUS
//feature/store/store_home:contract_test                                 PASSED in 1.4s
//utility/mc_analytics:consent_gate_test                                 PASSED in 0.8s
//utility/mc_analytics:di_test                                           PASSED in 1.3s
//utility/mc_analytics:no_third_party_test                               PASSED in 1.0s
//utility/mc_analytics:sessions_sinks_test                               PASSED in 1.2s
//utility/mc_analytics:validation_test                                   PASSED in 1.2s
//utility/mc_feature_flow:framework_navigation_baseline_test             PASSED in 1.7s

Executed 7 out of 62 tests: 7 tests pass and 55 were skipped.
```

### build --config=lint //... failed

```
INFO: Invocation ID: 66075662-530b-475e-bdcd-27f53c6b0e77
Computing main repo mapping: 
Loading: 
Loading: 0 packages loaded
Analyzing: 460 targets (15 packages loaded)
Analyzing: 460 targets (15 packages loaded, 0 targets configured)
Analyzing: 460 targets (15 packages loaded, 31 targets configured)

INFO: From DartCodegen @@//spike/api_envelope:_api_response_json_part:
ERROR: /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a65f99734c80fbc00/utility/mc_test_steps/BUILD.bazel:23:16: Checking Dart formatting of //utility/mc_test_steps:mc_test_steps failed: (Exit 1): dart failed: error executing DartFormat command (from aspects [@@ai_rules_dart+//dart/private:dart_analyzer_summary.bzl%dart_analyzer_summary, @@ai_rules_dart+//dart/private:dart_analyze_aspect.bzl%dart_analyze] on flutter_library rule target //utility/mc_test_steps:mc_test_steps) external/ai_rules_flutter++flutter+flutter_darwin-arm64/dart-sdk/bin/dart bazel-out/darwin_arm64-opt-exec/bin/external/ai_rules_dart+/dart/private/tools/format_runner.dill ... (remaining 1 argument skipped)
Changed utility/mc_test_steps/lib/src/backend/the_backend_runs_the_scenario.dart
Formatted 51 files (1 changed) in 0.18 seconds.
Analyzing: 460 targets (19 packages loaded, 1470 targets configured, 916 aspect applications)
INFO: Elapsed time: 2.598s, Critical Path: 0.78s
INFO: 4758 processes: 4369 action cache hit, 151 disk cache hit, 4588 internal, 19 worker.
ERROR: Build did NOT complete successfully
```

### dart format failed

```
Changed utility/mc_test_steps/lib/src/backend/the_backend_runs_the_scenario.dart
Formatted 957 files (1 changed) in 1.72 seconds.
```

### coverage >= 90 % (touched packages) failed

```
package:mc_analytics/src/analytics_di_initializer.dart: 22/22 100.0% missed=[]
package:mc_analytics/src/consent.dart: 3/3 100.0% missed=[]
package:mc_analytics/src/consent_store.dart: 10/10 100.0% missed=[]
package:mc_analytics/src/event.dart: 67/67 100.0% missed=[]
package:mc_analytics/src/lifecycle_observer.dart: 9/9 100.0% missed=[]
package:mc_analytics/src/records.dart: 7/7 100.0% missed=[]
package:mc_analytics/src/route_observer.dart: 32/32 100.0% missed=[]
package:mc_analytics/src/sinks.dart: 19/19 100.0% missed=[]
TOTAL 319/319 100.0%
== utility/mc_feature_flow
package:mc_feature_flow/src/feature_flow.dart: 130/131 99.2% missed=[230]
package:mc_feature_flow/src/flow_context.dart: 31/31 100.0% missed=[]
package:mc_feature_flow/testing.dart: 7/7 100.0% missed=[]
TOTAL 168/169 99.4%
== utility/mc_monitoring
package:mc_monitoring/src/monitoring.dart: 10/10 100.0% missed=[]
package:mc_monitoring/src/monitoring_di_initializer.dart: 0/5 0.0% missed=[8, 9, 11, 12, 13]
package:mc_monitoring/src/sinks.dart: 12/15 80.0% missed=[43, 44, 54]
TOTAL 22/30 73.3%
UNDER 90: utility/mc_monitoring
== utility/mc_formatters
package:mc_formatters/src/formatters.dart: 13/13 100.0% missed=[]
package:mc_formatters/src/formatters_di_initializer.dart: 3/3 100.0% missed=[]
package:mc_formatters/src/money.dart: 17/17 100.0% missed=[]
TOTAL 33/33 100.0%
```

**FAIL T-0056-AC8-gates**
