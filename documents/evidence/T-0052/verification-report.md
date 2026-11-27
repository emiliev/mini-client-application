# Verification report — T-0052: `mc_feature_flags` and the flags slice of `mc_fixtures_platform`

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, not the implementer)
- **Date:** 2026-11-27
- **Branch / commit verified:** `fleet/T-0052-feature-flags` @ `5700cd6`
- **Simulator:** none. No check needed e2e; the engineer's e2e summary (10 `mini_client` targets) was not re-run. The app-level boot test and `build --config=sim` were.
- **Verdict:** PASS

## Gates re-run independently
Bazel output base `/tmp/mc-ob-T-0052-verifier`, after `fvm dart pub get --offline`.

| Gate | Command | Result |
|---|---|---|
| All AC5 gates | `tool/checks/T-0052-AC5_gates.sh` ([output](verifier/AC5_gates_verifier.md)) | PASS, all 14 rows |
| Tests with the lockfile frozen | `test --lockfile_mode=error //...` | 163 of 163 pass |
| Lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, sim build | inside the gates script | PASS |
| Coverage, my own parser ([cov.py](verifier/cov.py), [output](verifier/coverage.txt)) | union of `DA:` lines over each package's `coverage.dat` | mc_feature_flags 416/423 = 98.3 %; mc_fixtures_platform 51/55 = 92.7 % (both at least 90 %, and the same as the engineer's) |
| Purity | closure checks in the gates | no Flutter marker for either package; positive and negative controls show the markers |
| Fixtures check | gates | 33 production targets, none reaches `mc_fixtures_platform`; both controls behave |

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0052-AC1 | Evaluation order override, remote, LKG, default; release-like envs reject; wrong type once; LKG after a failing restart; cache deleted on user change | `evaluation_test`, `registry_overrides_test` (33 `T-0052-AC1` tests); my probe [`verifier_probe_test.dart.txt`](verifier/verifier_probe_test.dart.txt) | yes. My independent probe passes: the four sources in order, `prod`, `release`, `staging`, `banana` and `''` all reject `set`, one report after five reads and a refetch, the LKG after a restart with `FailingPlatformDomain`, and after a user switch a failing restart sees the default | PASS |
| T-0052-AC2 | Golden table, split within 2 %, weight 0, forced variant, user changes subject | `experiments_test` (22 tests) | yes. I recomputed all 28 golden rows (not 5) in Python FNV-1a 32 ([script](verifier/golden_check.py), [output](verifier/golden_check.txt)): 28 of 28 match bucket and variant, including `''`, `user-é` and `é-exp`. My probe: weights `0,0,7` give `rich` to 200 subjects; a 1e15 weight is malformed and the declared 50/30/20 apply (all three variants occur); a forced variant wins | PASS |
| T-0052-AC3 | User switch refetches; stale epoch dropped in both orders; same-user re-sign-in reaches `watch`; failed fetch keeps values; dispose; boot not blocked | `session_fetch_test` (25), `di_test`, `registry_overrides_test`, app_core `feature_flags_boot_test` (4); my probe | yes. In my probe a held old-epoch response released after the new one is dropped; a `watch`-only subscriber sees the new value after `signIn` of the same user (via `epochChanges`); after `dispose` no request is made and the stream completes. `feature_flags_boot_test` holds the response on a completer (`held.release`), asserts home is shown, `calls == 1`, the default value, then `grid` after release | PASS |
| T-0052-AC4 | Seed 42 byte-identical, targeting, malformed scenario, set and scenario bodies equal, contract snapshots, purity, negative control | `flags_test` (7), `fixture_sets_test` (8, including a negative control), `provider_contract_test` (6, 10 snapshots plus a drift control), `no_flutter_test` | yes (read and run through `test //...`; the flags tests' `u-100` targeting and the identical set and scenario bodies are asserted) | PASS |
| T-0052-AC5 | Gates, coverage, lockfile, `MC_GENERATED_DART` | gates script, `--lockfile_mode=error`, own coverage parser | yes. Both `BUILD.bazel` globs exclude `MC_GENERATED_DART`. The dirty-package refusal is in the engineer's `mutations.sh` | PASS |

## Mutations (mine, [script](verifier/mutations.sh), [log](verifier/mutations.log))
Each mutant is applied in place, then run against the 5 test targets of `mc_feature_flags` (not my probe), then restored. 13 of 13 killed by a failing test.

| Id | Mutant | Result |
|---|---|---|
| M1 | last-known-good before the remote value | killed (2 targets) |
| M2 | no epoch check before the write (stale response applied) | killed (1) |
| M3 | `maxVariantWeight` raised to 1e15 | killed (1) |
| M4 | overrides always allowed (release-like env) | killed (2) |
| M5 | local override source skipped | killed (3) |
| M6 | bucket `<` becomes `<=` | killed (1) |
| M7 | FNV prime 403 becomes 402 | killed (1) |
| M8 | no cache delete on user change | killed (1) |
| M9 | last-known-good kept for another user | killed (1) |
| M10 | report on every read, not once | killed (3) |
| M11 | a zero-weight variant can win | killed (1) |
| M12 | `epochChanges` listener not installed (first try `if (false)` broke the build, redone as `&& _disposed`) | killed (1) |
| M13 | no notification after a successful fetch | killed (1) |

I did not re-run a sample of the engineer's 98; their log lists 98 killed and my 13 independent mutants on the same risk areas (order, epoch drop, weight cap, privacy) agree with it.

## Changes outside the package
- **`mc_session` `SessionEpochs.epochChanges`:** justified. Neither `authState` nor `SessionChanged` fires on a same-user sign-in, so a `watch`-only subscriber would never see the new epoch. The change is a separate interface, so the existing `SessionReader` test doubles are not affected. `Session` emits once per `signIn` and once per signed-in `signOut`, and closes the stream in `dispose`. It has a test (`T-0052-AC3 epochChanges ...`), the `mc_session` tests pass, and M12 shows the flags depend on it.
- **`app_core` root list and `appMockDomains`:** `FeatureFlagsDIInitializer` is right after `ApiAuthDIInitializer`, the comment is updated, and `PlatformMockDomain` is registered. `feature_flags_boot_test` pins both.
- **`boot_test.dart`:**
  - The two extra `tester.pump(10 ms)` calls only let Dio's zero timer fire, which is needed because the flags request now starts at boot. They remove no assertion.
  - The traffic assertion went from "the log has exactly 1 entry" to "the entries for `/v1/nothing` number 1". It still proves the probe request is recorded once. It no longer fails if some other unexpected request appears. That is a small loss of strictness, but it is necessary and declared.
- **`evaluation_test` control change** (the "owner uses the cache" control writes the cache after sign-in): correct, because the sign-in now deletes a cache written for nobody (privacy fix 9). I checked that M8 and M9 kill without that test being the only guard.

## Test-integrity audit
- Tests deleted, skipped or weakened: none. The only removed test line in the diff is the `boot_test.dart` traffic assertion above, which was replaced (declared).
- Lint suppressions added: none (grep for `ignore:`, `skip:` and `@Skip` over both packages and the new app_core test finds nothing).
- Golden files updated: none (10 new contract snapshots only).
- Every AC has `T-0052-ACn` tests.
- Globs use `MC_GENERATED_DART`.

## Issues found
1. (nit) `boot_test.dart` traffic assertion no longer checks that nothing else was requested. Acceptable; a TL decision whether to tighten it to the probe plus `/v1/flags`.
2. (nit) `feature_flags.dart` `_runFetch`: the cache write is issued after `_remote` is set, and a user switch deletes the cache without waiting for an in-flight write for the old user. The order within `FileStore` is not asserted for this case. Engineer tests with a backend that fails after the switch pass; I could not construct a failing interleaving with `FileStore`'s serialised writes, so this is not a defect.

No functional defects.

## Notes for the Tech Lead
- Evidence: `documents/evidence/T-0052/verifier/` (probe as `.txt`, `golden_check.py`, `cov.py`, `mutations.sh`, logs). My temporary probe target and file were removed from the tree; only evidence is committed.
- The `McTestContainer` follow-up (flags not in it) and the one-slot cache stay in the engineer's list for `pending-work.md`.

## Re-verification at d94971e (narrow, Sonnet tier, ADR-0011)
**Verdict: PASS.** Fresh Verifier, detached worktree at `d94971e` (the merge of `origin/main` `ed3c2cd` after the flaky-teardown fix). Logs are in `verifier/` (files `reverify_*`, `e2e_reverify/`).

### 1. Production diff (`914a8b9..d94971e`, `mc_feature_flags/lib`, `app_core/lib`)
- The kit change is only in `feature_flags.dart`: `_track`, `_writes`, `pendingWrites`, `settled()`. The `app_core` lib changes are T-0053's (`router_observers`, `root_initializers`).
- `settled()` covers: the install-id write (`_saveInstallId`; the retry is a later read that calls `_saveInstallId` again and so is tracked), the cache delete on a user change, and the cache write in `_runFetch`. It loops until `_writes` is empty, so a write that starts while it waits is awaited too, and it works on a copy (`List.of`), so removal during the wait is safe.
- **Override saves (`_saveOverrides`, line ~661) are not tracked.** That is fine by design: they are inside the `async` future that `setFlag`, `clearAll` and so on return, so the caller awaits them. A caller that drops that future is not covered by `settled()`. Nit only.
- Memory: each future is removed in `whenComplete` on both success and error, so no leak. Mutation 3 below shows the removal is what ends `settled()`.
- Failure: the tracking branch is `.then(onError: swallow)`, `settled()` swallows errors too, and `_track` returns the original future, so the callers see exactly what they saw before. A failing write cannot hang `settled()` or make it throw. The kit's stores return `Result`, not exceptions; the synchronous-throw case in `_saveInstallId` is caught before `_track`.
- Callers that never call `settled()`: behaviour is unchanged (same futures, same order, same error handling). The only additions are a `Set` entry per write and a handler that removes it.
- `root_initializers.dart` merge: `StorageDIInitializer`, `AnalyticsDIInitializer` right after it, and `FeatureFlagsDIInitializer` right after `ApiAuthDIInitializer`. Both are present, and the comment is accurate.

### 2. Tests
- `git diff 914a8b9..d94971e` over the test files: no assertion removed or weakened, no `ignore:`, `skip:` or `@Skip` added. Changes are teardown (`disposeAll`, `quiesce`, `TrackingStore` tracking deletes, `di_test` awaiting its stores) plus the boot test wait, plus T-0053's own tests.
- `Rig.quiesce()`: disposes flags, then 5 bounded rounds of `flags.settled()` + every `TrackingStore` write/delete + a zero delay, then the session. `disposeAll` quiesces every rig first and deletes the directories after, so nothing is deleted while a write runs.
- Boot test wait: a loop capped at 400 iterations (about 2 s of real time), each a real 5 ms `runAsync` delay plus a `pump`. It cannot hang, and it fails through `expect(pendingWrites, 0)` if it never settles. Under mutation 3 (futures never removed) it failed 50 of 50 runs in 4 s.

### 3. Flake proof (own runs)
`test --runs_per_test=200 --nocache_test_results` on 6 `mc_feature_flags` targets + `feature_flags_boot_test`:
- Idle: 1,400 runs, 0 failures, 0 flaky ([log](verifier/reverify_flake_idle.log)).
- Under load (8x `yes > /dev/null`, killed afterwards, `pgrep` shows none): 1,400 runs, 0 failures, 0 flaky ([log](verifier/reverify_flake_load.log)).

### 4. Mutations (own, 50 runs each on the 7 targets)
| # | Mutation | Result |
|---|---|---|
| 1 | cache delete on a user change no longer tracked (`_track(_store.delete(...))` -> `_store.delete(...)`) | **survived**: 7/7 pass, not flaky ([log](verifier/reverify_mut1_nodeltrack.log)) |
| 2 | `settled()` returns at once (`while (false && ...)`) | **survived**: 7/7 pass ([log](verifier/reverify_mut2_settled_noop.log)) |
| 3 | completion no longer removes the future from `_writes` | **killed**: 4 targets TIMEOUT 50/50 and the boot test FAILED 50/50 ([log](verifier/reverify_mut3_never_removed.log)) |

Mutations 1 and 2 survive because the tests have a second, independent guard: `TrackingStore` records every write and delete, and `Rig.quiesce` awaits those as well. So the kit's tracking of the delete, and `settled()` itself, are redundant for the teardown and no test pins them on their own. This does not make the tests flaky (the teardown is still safe), but nothing would catch a regression of `settled()` or of the delete tracking. Suggested follow-up (not a blocker): a unit test that holds a store write open and asserts `pendingWrites == 1` and that `settled()` completes only after it is released, for the cache write, the cache delete and the install id. Source restored after each mutation (`git status` clean).

### 5. Gates
- `tool/checks/T-0052-AC5_gates.sh` PASS ([log](verifier/reverify_AC5_gates.log)): closures, registration, fixtures check, `test //...` 176/176, lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, sim build, coverage mc_feature_flags 425/433 = 98.2 %, mc_fixtures_platform 51/55 = 92.7 %.
- `test --lockfile_mode=error //...`: 176/176 pass ([log](verifier/reverify_test_lockfile_error.log)).
- e2e: `tool/e2e_ios.sh --task T-0052 --role verifier` (the script rejects the name `T-0052-reverify`, so the simulator was `mc-T-0052-verifier-47889`) on a project copy from `tool/e2e/prepare_pub_project.sh`, **all 11 mini_client targets PASS**, including `analytics_screens_test` with analytics and flags both in the boot path ([summary](verifier/e2e_reverify/e2e-summary.md)). A first attempt against the raw `app/mini_client` failed in 11/11 only because that tree has no Xcode project; its simulator was deleted too. `simctl list` shows no `mc-T-0052` device.

### Defects
None. Nits: the two surviving mutations above (tests do not pin `settled()` / the delete tracking independently); `_saveOverrides` is not tracked by design.
