# T-0067: 50-run flake check (`test --runs_per_test=50 --nocache_test_results`) at 1395b9ab

```
//app/mini_client:analytics_screens_test                                 PASSED in 7.2s
  Stats over 50 runs: max = 7.2s, min = 5.2s, avg = 5.9s, dev = 0.6s
//app/mini_client:comic_route_test                                       PASSED in 5.0s
  Stats over 50 runs: max = 5.0s, min = 2.5s, avg = 3.1s, dev = 0.7s
//app/mini_client:deep_link_back_stack_test                              PASSED in 7.1s
  Stats over 50 runs: max = 7.1s, min = 4.7s, avg = 5.1s, dev = 0.7s
//app/mini_client:search_route_test                                      PASSED in 6.4s
  Stats over 50 runs: max = 6.4s, min = 3.9s, avg = 4.6s, dev = 0.6s
//app/wiring/universe_wiring:routes_test                                 PASSED in 2.4s
  Stats over 50 runs: max = 2.4s, min = 1.4s, avg = 1.8s, dev = 0.2s
//feature/characters/characters_details:architecture_test                PASSED in 0.8s
  Stats over 50 runs: max = 0.8s, min = 0.3s, avg = 0.3s, dev = 0.1s
//feature/characters/characters_details:bdd_test                         PASSED in 17.4s
  Stats over 50 runs: max = 17.4s, min = 9.3s, avg = 13.0s, dev = 2.7s
//feature/characters/characters_details:bloc_guards_test                 PASSED in 2.0s
  Stats over 50 runs: max = 2.0s, min = 1.1s, avg = 1.3s, dev = 0.2s
//feature/characters/characters_details:contract_test                    PASSED in 2.0s
  Stats over 50 runs: max = 2.0s, min = 1.0s, avg = 1.6s, dev = 0.2s
//feature/characters/characters_details:flow_scope_test                  PASSED in 5.6s
  Stats over 50 runs: max = 5.6s, min = 1.5s, avg = 2.5s, dev = 1.0s
Executed 10 out of 10 tests: 10 tests pass.
```

Per-target run logs (each `run_N_of_50`), counted from `bazel-testlogs` after the run:

| target | run logs | failed |
|---|---|---|
| //feature/characters/characters_details:bdd_test | 50 | 0 |
| //feature/characters/characters_details:bloc_guards_test | 50 | 0 |
| //feature/characters/characters_details:contract_test | 50 | 0 |
| //feature/characters/characters_details:flow_scope_test | 50 | 0 |
| //feature/characters/characters_details:architecture_test | 0 | 0 |
| //app/wiring/universe_wiring:routes_test | 50 | 0 |
| //app/mini_client:analytics_screens_test | 50 | 0 |
| //app/mini_client:comic_route_test | 50 | 0 |
| //app/mini_client:deep_link_back_stack_test | 50 | 0 |
| //app/mini_client:search_route_test | 50 | 0 |
