# T-0029-AC6: gates (Engineer, 53ef1c1 + docs commit)

Run on the committed MODULE.bazel (pin + queue `0003-ext-bdd-generator.patch`), no `.bazelrc.user` override, `--output_base=/tmp/mc-ob-T-0029-engineer`. `tool/verify.sh` does not exist yet, so its gates were run one by one.

## `tool/rules_fork.sh check ai_rules_dart`
```
check ai_rules_dart: 1 patch(es) apply strictly on pin e7163aab8f91
```
## `tool/bazelw test //... --keep_going --nocache_test_results`
```
//app/mini_client:app_test                                               PASSED in 1.2s
//app/wiring/app_core:boot_test                                          PASSED in 1.0s
//app/wiring/app_core:links_and_hooks_test                               PASSED in 0.5s
//spike/bdd_sample:bdd_test                                              PASSED in 1.3s
//spike/hello:widget_test                                                PASSED in 0.8s
//tool/l10n_check:l10n_check_test                                        PASSED in 0.2s
//tool/l10n_check:workspace_gate_test                                    PASSED in 0.2s
//tool/mc_arch_check:arch_check_test                                     PASSED in 0.3s
//utility/mc_analysis:lints_test                                         PASSED in 2.8s
//utility/mc_api_client:api_client_test                                  PASSED in 0.4s
//utility/mc_api_client:no_flutter_test                                  PASSED in 0.2s
//utility/mc_api_errors:api_failure_test                                 PASSED in 0.2s
//utility/mc_api_errors:no_flutter_test                                  PASSED in 0.2s
//utility/mc_bloc_kit:feature_flow_controller_test                       PASSED in 0.2s
//utility/mc_bloc_kit:mc_bloc_test                                       PASSED in 0.2s
//utility/mc_bloc_kit:purity_test                                        PASSED in 0.2s
//utility/mc_config:app_config_test                                      PASSED in 0.2s
//utility/mc_config:bundled_config_test                                  PASSED in 0.2s
//utility/mc_di:di_container_test                                        PASSED in 0.3s
//utility/mc_di:recording_test                                           PASSED in 0.3s
//utility/mc_ds_buttons:buttons_test                                     PASSED in 1.3s
//utility/mc_ds_buttons:golden_test                                      PASSED in 1.0s
//utility/mc_ds_feedback:feedback_test                                   PASSED in 0.8s
//utility/mc_ds_feedback:golden_test                                     PASSED in 1.4s
//utility/mc_ds_layout:golden_test                                       PASSED in 1.3s
//utility/mc_ds_layout:layout_test                                       PASSED in 1.1s
//utility/mc_ds_theme:golden_test                                        PASSED in 0.9s
//utility/mc_ds_theme:theme_test                                         PASSED in 0.7s
//utility/mc_ds_tokens:tokens_test                                       PASSED in 0.5s
//utility/mc_event_bus:event_bus_test                                    PASSED in 0.2s
//utility/mc_event_bus:no_flutter_test                                   PASSED in 0.2s
//utility/mc_feature_flow:feature_flow_test                              PASSED in 1.3s
//utility/mc_fixtures_characters:characters_test                         PASSED in 0.9s
//utility/mc_fixtures_characters:provider_contract_test                  PASSED in 0.4s
//utility/mc_fixtures_media:bundled_image_resolver_test                  PASSED in 0.5s
//utility/mc_formatters:formatters_test                                  PASSED in 0.2s
//utility/mc_l10n_core:l10n_test                                         PASSED in 0.6s
//utility/mc_mocked_backend:mocked_backend_test                          PASSED in 1.8s
//utility/mc_monitoring:monitoring_test                                  PASSED in 0.2s
//utility/mc_monitoring:no_flutter_test                                  PASSED in 0.2s
//utility/mc_prelude:result_test                                         PASSED in 0.2s
//utility/mc_storage:file_store_test                                     PASSED in 0.2s
//utility/mc_storage:no_flutter_test                                     PASSED in 0.2s
//utility/mc_test_steps:data_table_test                                  PASSED in 0.3s
//utility/mc_test_utils:fonts_test                                       PASSED in 0.5s
//utility/mc_test_utils:golden_test                                      PASSED in 0.8s
//utility/mc_test_utils:harness_test                                     PASSED in 1.4s
//utility/mc_test_utils:init_flow_test                                   PASSED in 1.2s
//utility/mc_test_utils:isolation_test                                   PASSED in 0.5s
EXIT 0
Executed 49 out of 49 tests: 49 tests pass.
```
## `tool/bazelw build --config=lint //...`
```
INFO: Build completed successfully, 1 total action
LINT EXIT 0
```
## `tool/bazelw run //tool/mc_arch_check:bin`
```
mc_arch_check: OK (/Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a5202de903259c057)
ARCH EXIT 0
```
## Fork tests: `tool/bazelw test @rules_dart//dart/ext/bdd:all @rules_dart//dart/ext/_shared/combining_shim:all`
```
@rules_dart//dart/ext/bdd:bdd_generator_test                    (cached) PASSED in 0.3s
@rules_dart//dart/ext/_shared/combining_shim:combining_test              PASSED in 0.2s
FORK EXIT 0
```
## Upstream draft
- `documents/upstream/U-D-bdd/README.md`

**PASS T-0029-AC6**
