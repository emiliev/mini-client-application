# T-0063 review round: 50-run flake check on the changed targets

`test --runs_per_test=50 --nocache_test_results`, after the review-round fixes.

```
//app/mini_client:app_test                                               PASSED in 2.6s
//app/mini_client:settings_route_test                                    PASSED in 3.3s
//app/wiring/app_core:appearance_shell_test                              PASSED in 2.0s
//feature/settings/settings_appearance:bdd_test                          PASSED in 4.1s
//feature/settings/settings_appearance:contract_test                     PASSED in 0.5s
//feature/settings/settings_appearance:flow_scope_test                   PASSED in 1.9s
//utility/mc_appearance:di_test                                          PASSED in 0.6s
//utility/mc_appearance:local_test                                       PASSED in 0.4s
//utility/mc_appearance:preferences_test                                 PASSED in 0.4s
//utility/mc_appearance:races_test                                       PASSED in 0.5s
//utility/mc_appearance:sync_test                                        PASSED in 0.6s
Executed 11 out of 11 tests: 11 tests pass.
```

| target | run logs | failed |
|---|---|---|
| //utility/mc_appearance:preferences_test | 50 | 0 |
| //utility/mc_appearance:local_test | 50 | 0 |
| //utility/mc_appearance:sync_test | 50 | 0 |
| //utility/mc_appearance:races_test | 50 | 0 |
| //utility/mc_appearance:di_test | 50 | 0 |
| //feature/settings/settings_appearance:bdd_test | 50 | 0 |
| //feature/settings/settings_appearance:flow_scope_test | 50 | 0 |
| //feature/settings/settings_appearance:contract_test | 50 | 0 |
| //app/wiring/app_core:appearance_shell_test | 50 | 0 |
| //app/mini_client:settings_route_test | 50 | 0 |
| //app/mini_client:app_test | 50 | 0 |
