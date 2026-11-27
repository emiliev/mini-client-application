# Verification report — T-0053: `mc_analytics` (U06), the tracking facade with a consent gate

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0053-analytics` @ `5d1a596` (includes `origin/main` at `fb0b049`)
- **Simulator:** `mc-T-0053-verifier-13107`, iPhone 17 Pro, iOS 26.2 (created and deleted by the Verifier; confirmed gone in `simctl list`)
- **Verdict:** **PASS**

Own Bazel output bases (`/tmp/mc-ob-T-0053-verifier*`), own e2e project copy; the TL worktree was not touched, nothing pushed. Supporting evidence is in `documents/evidence/T-0053/verifier/`.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All AC5 gates | `tool/checks/T-0053-AC5_gates.sh` (own output base) | PASS, 12/12 rows (`gates.md`): no network client or SDK in the closure (with positive and negative controls), globs use `MC_GENERATED_DART`, registration, `test //...`, `test --lockfile_mode=error //...`, bundled config dev/e2e/perf, lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, coverage |
| Tests | the script's `test //...` (touched packages uncached) | 40 of 40 pass |
| Coverage (own parser, `cov.py` over the `coverage.dat` files) | `mc_analytics` | 293/293 lines = 100 % (all 9 `lib/src` files seen). The script's own parser: `mc_config` 24/24, `app_core` 437/454 = 96.3 %, `mini_client` 109/114 = 95.6 % (my parser covered `mc_analytics` only) |
| Flake check | `test --runs_per_test=50 --nocache_test_results` on 6 `mc_analytics` targets, `analytics_screens_test`, `mc_config` (2 targets), plus `router_observers_test`, `formatters_root_test`, `analytics_steps_test`, `bdd_test` | 0 failures in 13 targets x 50 runs (`flake50.log`) |
| L4 E2E | `tool/e2e_ios.sh --task T-0053 --role verifier` on a project copy from `tool/e2e/prepare_pub_project.sh`, **all 11 targets** | 11/11 PASS, including `analytics_screens_test.dart` (`e2e-summary.md`) |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0053-AC1 | unknown / denied deliver 0; unknown to granted flushes in order; unknown to denied discards; buffer 100/101; same-turn denied; persistence; reset | `consent_gate_test`, `di_test`, `app_config_test`, `bundled_config_test`, `mini_client/analytics_screens_test` (all named `T-0053-AC1`). My own probe `zz_probe_test.dart.txt`, 13 tests, all pass (`probe_result.txt`) | yes. The probe re-derived each point: 0 entries across track, screen and user property; the flush has seq 1..5 with the right session; 99 user entries plus the session start fill 100 and nothing drops; 100 user entries drop the oldest (the session start) and seq is 1..100; `denied` before and after `track` in one turn delivers nothing; consent survives a new `ConsentStore` on a real directory; a garbage file reads `unknown` (not the granted default); `reset()` under granted delivers the queued event under the old session, then a new session starts; under unknown it drops the buffer | PASS |
| T-0053-AC2 | validation boundaries, debug throws, release drops and reports once | `validation_test` (`T-0053-AC2`); probe | yes. Name 40/41, empty, upper case, hyphen and `__` rejected; params 25/26; string 100/101; 4 reserved prefixes and 3 reserved keys; debug gives `AssertionError`; release (`debugMode: false`) gives 0 delivered and exactly 1 `ErrorEntry` per rejected call (3 calls, 3 errors); `screen()` takes 24 params and rejects 25 | PASS |
| T-0053-AC3 | rotation at 30 min, cold start, seq, throwing sink, monitoring sink | `sessions_sinks_test`, `di_test`, `no_third_party_test`; probe | yes. 29:59 keeps the session and 30:00 rotates; the new session's seq is 1, 2; two instances give different session ids; a throwing sink is called for every entry, the other sink still gets them, and it is reported once; `MonitoringAnalyticsSink` forwards as `EventEntry` | PASS |
| T-0053-AC4 | screens: real GoRouter, app level, BDD steps, e2e | `route_observer_test`, `router_observers_test`, `analytics_screens_test` (app), `app_screens.feature` (3 scenarios, `@T-0053-AC4`), `analytics_steps_test`, e2e `analytics_screens_test` | yes. Home, Characters, Back records exactly `home, characters_list, home`. Observer without re-track on pop: `bdd_test` red (X11). A mutation that tracks unnamed or nested paths, dedupe removed, dialogs tracked: all caught. With no container, navigation works (X07 mutation shows the tests catch a throw). Removing the `name:` of `characters_list` makes `analytics_screens_test` (the route-tree naming test) and `bdd_test` fail | PASS |
| T-0053-AC5 | gates, e2e, scripts | `T-0053-AC5_gates.sh`, `mutations.sh` | yes, see the gates table above. The mutation script refuses a dirty tree and tells BROKEN from KILLED (read; also used by me) | PASS |

Visual checkpoints (e2e, iPhone 17 Pro, 1200 px tall):

| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Characters list | `documents/evidence/T-0053/verifier/02_characters_list.png` | the Characters list screen after tapping Characters from home | yes (the e2e asserts `home, characters_list`) |
| Back to home | `documents/evidence/T-0053/verifier/03_back_to_home.png` | home again after Back (the e2e asserts `home, characters_list, home`) | yes |

## Mutations
- **Engineer's, re-run (9 of 102, `mut_engineer.log`):** G01, G02, G04, G18, S01, S02, X06, X07, X11: **9/9 killed**, none broken, tree clean after. X11 (observer does not re-track on pop) is killed by `bdd_test`, as asked.
- **My own, 10 (`vmut.py`, `vmut.log`):** **10/10 killed**, tree clean after.

| # | Mutation | Killed by |
|---|---|---|
| V01 | seq starts at 2 | consent_gate, sessions_sinks, validation, app analytics_screens |
| V02 | buffer cap 101 | consent_gate |
| V03 | `denied` keeps the buffer | consent_gate |
| V04 | `reset` drops queued granted entries | consent_gate |
| V05 | damaged saved value falls back to the default | consent_gate |
| V06 | observer without the same-route dedupe | route_observer |
| V07 | observer tracks non-page routes (dialogs) | route_observer |
| V08 | 26 params allowed | validation |
| V09 | string length in UTF-16 units | validation |
| V10 | a throwing sink reported on every entry | sessions_sinks |

Mutants were built without the analyzer (`--output_groups=-dart_analyze,-dart_format`), as the engineer's script does, so a failure is a test failure and not a build error.

## Changes outside the package
- **`mc_config`:** `AnalyticsConfig` is optional; a missing key, wrong type or non-object is `unknown`. `dev.json` and `e2e.json` say `granted`; `perf.json` is untouched (`unknown`). `bundled_config_test` now asserts it for all three envs (an added assertion, so stronger).
- **`app_core`:** `AnalyticsDIInitializer` is placed after Storage and not after Monitoring. This is justified: it reads `FileStore` for the saved consent (and `Monitoring`, `AppConfig`), so it must come after Storage, and the doc comment and the `isolation_test` comment say why. Nothing between Monitoring and Storage needs it. `appRouterObservers` is lazy and returns null when `Analytics` is not registered (tested).
- **Route names:** `app_locations.dart` is not in the diff; the paths (`/`, `/characters`, `:id`, `/search`, ...) are unchanged and only `name:` was added to the typed routes. The e2e deep-link journeys (all PASS) confirm the URLs.
- **`mc_test_utils` / `mc_test_steps`:** `McTestSession.analytics`, the initializer in `McTestContainer` (consent granted, no lifecycle observer), and 5 steps with negative controls in `analytics_steps_test`.
- **Edits to existing tests, none weakened:** `formatters_root_test` (+`ensureInitialized()` only); `isolation_test` 9 to 10 initializers with a comment; `bundled_config_test` (+1 assertion); `app_config_test` (additions). The two widget tests that "now use `runAsync`" are in the new `di_test.dart`, not old tests, and the change makes them await the consent save before teardown (F-0050 rule).

## Test-integrity audit
- Tests deleted, skipped or weakened: none (the only removed test line is `expect(... length, 9)`, replaced by `10`, with the new initializer listed).
- Lint suppressions added: none (`grep` for `ignore:`, `ignore_for_file` and `skip:` over the touched packages found nothing).
- Golden files updated: none.
- Every AC has a `T-0053-ACn` test or script (grep checked: AC1 in 5 files, AC2, AC3, AC4 in 8, AC5 in `T-0053-AC5_gates.sh`).
- No network client or SDK: the closure check (2380 targets) found no marker, and the positive and negative controls fire.

## Issues found
None blocking.
1. (nit, no action) My first probe run failed on one expectation of mine (the old session's seq for `signed_out` is 2, because `mc_session_start` had seq 1). The code was right and the probe was wrong; the probe in the evidence is the corrected one.
2. (observation, not a defect) My own coverage parser covered `mc_analytics` only (293/293); the other packages' numbers are the gates script's.

## Notes for the Tech Lead
- Pages inside a `McFlowPage` flow and the universe sandbox router are not tracked (documented in F-0053), so a follow-up task is needed when those screens must count.
- Flag-exposure events, a network sink and the privacy screen stay out of scope, as stated.
- Evidence files: `gates.md`, `flake50.log`, `probe_result.txt` with `zz_probe_test.dart.txt` (the probe, kept as text and removed from the tree), `vmut.py` / `vmut.log`, `mut_engineer.log`, `e2e-summary.md`, 2 screenshots.
