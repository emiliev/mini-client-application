# T-0064: 50-run flake check (DoD)

At `ab02b7d` (the merge with `origin/main` plus the gates report), on its own output base:

```
tool/bazelw test --runs_per_test=50 --nocache_test_results --local_test_jobs=6 //feature/trivia/trivia_quiz/... //app/wiring/chronicle_wiring:routes_test //app/mini_client:trivia_route_test //app/mini_client:analytics_screens_test //utility/mc_fixtures_editorial/...
```

Every target T-0064 adds or changes, the timer tests included (the BDD target holds the countdown outlines, the background and quit pauses; `flow_scope_test` the covered pause and the seed draw; `painter_test` the ring over 20 s of fake time). **15 targets x 50 runs = 750 runs, 0 failures, 0 flaky.** An earlier run at `c452086` was 750 of 750 too.

```
//app/mini_client:analytics_screens_test                                 PASSED in 4.2s
//app/mini_client:trivia_route_test                                      PASSED in 3.3s
//app/wiring/chronicle_wiring:routes_test                                PASSED in 1.5s
//feature/trivia/trivia_quiz:architecture_test                           PASSED in 0.3s
//feature/trivia/trivia_quiz:bdd_test                                    PASSED in 15.3s
//feature/trivia/trivia_quiz:contract_test                               PASSED in 0.8s
//feature/trivia/trivia_quiz:flow_scope_test                             PASSED in 3.0s
//feature/trivia/trivia_quiz:golden_test                                 PASSED in 4.8s
//feature/trivia/trivia_quiz:outline_matches_contract_test               PASSED in 0.5s
//feature/trivia/trivia_quiz:painter_test                                PASSED in 2.3s
//utility/mc_fixtures_editorial:determinism_test                         PASSED in 1.6s
//utility/mc_fixtures_editorial:fixture_sets_test                        PASSED in 3.2s
//utility/mc_fixtures_editorial:provider_contract_test                   PASSED in 2.9s
//utility/mc_fixtures_editorial:scoring_test                             PASSED in 1.0s
//utility/mc_fixtures_editorial:validation_test                          PASSED in 1.2s
Executed 15 out of 15 tests: 15 tests pass.
```

## After ADR-0015 (no goldens, the engine unit tests), at `af88b09`

The feature's targets changed (`golden_test` deleted, `painter_test` now runs in 4 themes, `engine_test` and the architecture check added), so its whole package ran again: `test --runs_per_test=50 --nocache_test_results //feature/trivia/trivia_quiz/...`. **7 targets x 50 runs = 350 runs, 0 failures, 0 flaky.** The other targets of the first table did not change.

```
//feature/trivia/trivia_quiz:architecture_test                           PASSED in 1.0s
//feature/trivia/trivia_quiz:bdd_test                                    PASSED in 27.1s
//feature/trivia/trivia_quiz:contract_test                               PASSED in 2.0s
//feature/trivia/trivia_quiz:engine_test                                 PASSED in 0.8s
//feature/trivia/trivia_quiz:flow_scope_test                             PASSED in 7.6s
//feature/trivia/trivia_quiz:outline_matches_contract_test               PASSED in 0.4s
//feature/trivia/trivia_quiz:painter_test                                PASSED in 7.1s
Executed 7 out of 7 tests: 7 tests pass.
```
