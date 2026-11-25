# T-0034-AC5: gates and coverage

| Gate | Result |
|---|---|
| test //... (touched packages uncached) | **FAIL** |
| build --config=lint //... | PASS |
| mc_arch_check | PASS |
| rules_fork.sh check | PASS |
| dart format | PASS |
| l10n_check | PASS |
| coverage >= 90 % (touched packages) | PASS |

- tests: Executed 1 out of 77 tests: 76 tests pass and 1 fails locally.
- coverage: == feature/characters/characters_list TOTAL 155/155 100.0% == utility/mc_feature_flow TOTAL 133/136 97.8% == utility/mc_paging TOTAL 117/117 100.0% == utility/mc_config TOTAL 19/19 100.0% == utility/mc_api_client TOTAL 67/68 98.5% == utility/mc_mocked_backend TOTAL 273/295 92.5% == utility/mc_test_utils TOTAL 309/355 87.0% UNDER 90 (exempt, pre-existing): utility/mc_test_utils (threshold 90 %)

### test //... (touched packages uncached) failed

```
//utility/mc_media:purity_test                                  (cached) PASSED in 0.2s
//utility/mc_media:resolved_image_test                          (cached) PASSED in 0.2s
//utility/mc_mocked_backend:mocked_backend_test                 (cached) PASSED in 1.8s
//utility/mc_monitoring:monitoring_test                         (cached) PASSED in 0.3s
//utility/mc_monitoring:no_flutter_test                         (cached) PASSED in 0.2s
//utility/mc_paging:copywith_barrel_test                        (cached) PASSED in 0.2s
//utility/mc_paging:debounced_query_test                        (cached) PASSED in 0.2s
//utility/mc_paging:paged_state_test                            (cached) PASSED in 0.2s
//utility/mc_paging:paging_controller_test                      (cached) PASSED in 0.3s
//utility/mc_paging:purity_test                                 (cached) PASSED in 0.2s
//utility/mc_paging:search_history_test                         (cached) PASSED in 0.3s
//utility/mc_prelude:result_test                                (cached) PASSED in 0.6s
//utility/mc_storage:file_store_test                            (cached) PASSED in 0.2s
//utility/mc_storage:no_flutter_test                            (cached) PASSED in 0.2s
//utility/mc_test_steps:data_table_test                         (cached) PASSED in 0.4s
//utility/mc_test_utils:fonts_test                              (cached) PASSED in 0.7s
//utility/mc_test_utils:golden_test                             (cached) PASSED in 1.0s
//utility/mc_test_utils:harness_test                            (cached) PASSED in 1.3s
//utility/mc_test_utils:init_flow_test                          (cached) PASSED in 1.1s
//utility/mc_test_utils:isolation_test                          (cached) PASSED in 0.7s
//app/wiring/app_core:boot_test                                          FAILED in 2.7s
  /private/tmp/mc-ob-T-0034-engineer/execroot/_main/bazel-out/darwin_arm64-fastbuild/testlogs/app/wiring/app_core/boot_test/test.log

Executed 1 out of 77 tests: 76 tests pass and 1 fails locally.
There were tests whose specified size is too big. Use the --test_verbose_timeout_warnings command line option to see which ones these are.
```

**FAIL T-0034-AC5-gates**
