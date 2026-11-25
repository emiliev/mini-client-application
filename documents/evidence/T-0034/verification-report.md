# Verification report: T-0034 Remove the `characters_list` exemplar's workarounds

- **Verifier:** crew: Verifier (a fresh agent; not the implementer)
- **Date:** 2026-11-25
- **Branch / commit verified:** `fleet/T-0034-exemplar-workarounds` @ **`8d7599c`**, a detached checkout in the Verifier's own worktree
- **Simulator:** none. This is a kit and package task, verified with unit, widget, BDD, golden and check-script tests. No app journey changed.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0034-verifier …`, a new output base. `.bazelrc` still uses the shared disk cache, so every test run that counts here used `--nocache_test_results`. The server was shut down at the end.
- **Verdict: PASS.** All six ACs pass. The kit changes match the TL decisions. There are no blockers and no majors. Five minor issues and two nits are listed under "Issues found". None of them makes an AC fail.

My evidence is in [`verifier/`](verifier/).

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Touched packages, uncached | `test --nocache_test_results` over `characters_list`, `mc_feature_flow`, `mc_paging`, `mc_config`, `mc_api_client`, `mc_mocked_backend`, `mc_test_utils`, `app_core`, `mini_client` | **27/27 PASSED** ([test_touched_uncached.txt](verifier/test_touched_uncached.txt)). I also ran it once at the start (26/26) |
| Everything, uncached | `test --nocache_test_results //...` | **Executed 77 out of 77 tests: 77 tests pass.** The `app_core:boot_test` fix in 8d7599c holds, so the Outcome's "76/77" is stale |
| Lint | `build --config=lint //...` | exit 0 |
| Arch | `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Rules fork | `tool/rules_fork.sh check` | exit 0. `ai_rules_dart: 3 patch(es) apply strictly on pin e7163aab8f91`; `ai_rules_flutter: queue empty, OK` |
| Format | `fvm flutter pub get --offline`, then `fvm dart format --output=none --set-exit-if-changed app feature spike utility tool/l10n_check tool/mc_arch_check` | 364 files, 0 changed, exit 0 |
| l10n | `run //tool/l10n_check:bin -- <repo>` | `l10n_check: OK` |
| Coverage | `coverage --nocache_test_results` over the 7 touched packages (24/24 pass), then my own parser, [coverage_t0034.py](verifier/coverage_t0034.py). It is written independently of `merge_lcov.py` | [coverage.txt](verifier/coverage.txt): characters_list **155/155 = 100 %**; mc_feature_flow **133/136 = 97.8 %** (misses `feature_flow.dart:213`, `flow_context.dart:34`, `testing.dart:17`); mc_paging **117/117 = 100 %**; mc_config **19/19 = 100 %**; mc_api_client **67/68 = 98.5 %**; mc_mocked_backend **277/295 = 93.9 %** (the engineer reports 92.5 %; both are ≥ 90); mc_test_utils **309/355 = 87.0 %**. mc_test_utils is exempt by TL decision: `fixture_assets.dart` is at 0/37 in-package, as on main, and the changed `test_container.dart` is at 31/31 |
| Lock | `git diff origin/main...HEAD -- pubspec.lock MODULE.bazel.lock` | No change. `get_it ^8.0.0` and `mc_l10n_core` resolve offline |

## Acceptance criteria
| AC | Mapped test(s) | Does the test really assert the AC? | Result |
|---|---|---|---|
| T-0034-AC1 | `//utility/mc_feature_flow:flow_kit_test`: "T-0034-AC1 context.di inside BlocProvider.create does not throw and creates the bloc once" and "T-0034-AC1 context.di registers no dependency on the scope and a new scope does not recreate the bloc" | **Yes.**<br>- **Test 1** uses a real `FeatureFlow` and a page shaped like plan 01's (`BlocProvider(create: (context) => context.di<…>())`). It asserts no exception on mount or on unmount, and that the bloc is created once.<br>- **Test 2** swaps the scope's container under one widget instance. The listening control rebuilds (2), so the scope did notify. The `di` probe does not rebuild (1), and the bloc count stays the same.<br>- **My mutation M1** puts `FlowScope.of` back in `di`. `flow_kit_test` fails 3 of 7 tests: test 1 with "Tried to listen to an InheritedWidget in a life-cycle that will never be called again", and test 2 with `plainBuilds` Expected 1, Actual 2. AC2 `provide:` also fails. `characters_list:bdd_test` fails as well ([m1_flow_kit_detail.log](verifier/m1_flow_kit_detail.log)).<br>- **Escape probe P2.** After the flow is disposed, `di` on a captured page context throws ("Looking up a deactivated widget's ancestor is unsafe"). A captured container throws `GetIt: … _Provided is not registered`, because the child was reset. The hook throws as well. In release, `_inheritedElements` is nulled on unmount, so `read` throws "not below a FeatureFlow", the same as `of` did. `FlowScope.read` opens no new escape: `of` already exposed `.container` | **PASS** |
| T-0034-AC2 | `flow_kit_test`: "T-0034-AC2 provide: resolves inside the flow and nowhere outside it", "… localizationsDelegates resolve the flow strings in en and de", "… without localizationsDelegates the host decides" | **Yes.** The provided instance resolves inside the flow. A sibling flow can't resolve it, and neither can the root (`diContainer.isRegistered` is false).<br>- **My probes:** after dispose, the instance can't be reached (P2). An inner flow nested inside the outer flow's page can't resolve it either (P4).<br>- **Ordering:** `provide` runs before `flowInitializer` (`feature_flow.dart:169-171`). P1 has an initializer that eagerly resolves the provided instance, and it passes. With the order swapped (M3/M3P), P1 fails. **No committed test pins this order:** M3 survives `flow_kit_test`, `bdd_test` and `flow_scope_test` (Issue 2). The exemplar's injectable registrations are lazy, which is why nothing else catches it.<br>- **l10n:** the feature's strings plus the core `Retry` resolve in en. de gives "Hallo". Dropping the core and Flutter delegates (M6) or the feature delegates (M7) fails `flow_kit_test` and `bdd_test`.<br>- **Exactly once?** The flow adds `mcLocalizationsDelegates` once. But `Localizations.override` prepends them to the host's list, so a host that already installs them ends up with duplicates in the merged list (P3: core ×2, Material ×2, Widgets ×3, Cupertino ×2). Flutter loads only the first delegate per type, so each resource still loads once. The flow's delegates win, though: **a host's own `MaterialLocalizations` override is shadowed inside the flow** (P3 reads `OK`, not the host's `CUSTOM-OK`) (Issue 1). The T-0032 workaround behaved the same, so this is not a regression | **PASS** |
| T-0034-AC3 | `//utility/mc_paging:copywith_barrel_test`: "T-0034-AC3 a freezed state holding PagedState has the default copyWith", "… the deep copyWith reaches into the PagedState", "… a union case holding PagedState compiles and reads" | **Yes.** The fixture `test/support/holder_state.dart` imports only the barrel. The Bazel freezed shim generates it with the default `copyWith`, and the test calls `copyWith.page(hasReachedEnd:, total:)`.<br>- **My mutation M10** removes `$PagedStateCopyWith` from the barrel. `copywith_barrel_test` **and** `characters_list:bdd_test` both FAIL TO BUILD (kernel compile errors).<br>- **Byte identity, regenerated by me:** `T-0032-AC6_matches_build_runner.sh` with my output base gives **11 of 11 EQUAL**. build_runner ran in a fresh overlay ("wrote 8 outputs", then "wrote 5 outputs") ([report](verifier/T-0032-AC6_matches_build_runner.md)). The Bazel-built bloc `.freezed.dart` holds **3** `$PagedStateCopyWith` references. The API `.g.dart` hash moved from `36401c9e…` to `505ba74b…`, as it should, because it now holds `'v1/characters'` | **PASS** |
| T-0034-AC4 | `mc_config:app_config_test` "T-0034-AC4 …" ×3; `mc_api_client:api_client_test` "T-0034-AC4 …" ×3; `tool/checks/T-0034-AC4_relative_paths.sh`; the BDD traffic steps | **Yes.**<br>- **Normalisation:** `https://api.test` becomes `https://api.test/`, `…/v2` becomes `…/v2/`, and a value that already ends with `/` is kept. The constructor asserts and names the value. M11 (no normalisation) fails `app_config_test`, `app_core:boot_test` and `mini_client:app_test`. M13 (always append, so `//`) fails `app_config_test`. M12 (drop the `createApiDio` assert) fails `api_client_test`.<br>- **Non-const `AppConfig`:** this is sensible. `String.endsWith` can't run in a const assert, and its only const user (`McTestContainer.config`) is now `static final`. T-0033's branch adds no new `const AppConfig(`.<br>- **Configs and defaults:** `dev`, `e2e` and `perf.json`, `defaultApiBaseUrl`, `MockBackend.createDio` and `McTestContainer.config` all end with `/`. The JSON strings in `app_test` and `boot_test` don't, and `fromJson` normalises them, which `boot_test` now asserts.<br>- **Traffic:** the BDD asserts `the backend received {'GET /v1/characters?offset=0&limit=30'}` and the request counts against the harness's recorded requests. M15 (`'v2/characters'`) fails `bdd_test`. M14 (back to `'/v1/characters'`) passes every test, as F-0033 fact 5 says: Dio collapses `//`. The script is what catches it.<br>- **Script:** PASS on HEAD, with its planted control tripped. My plant of `@GET('/v1/characters')` in the exemplar gives **FAIL**, and so does a double-quoted `@POST("/v1/b")` in `app/`. A multi-line `@GET(\n '/v1/…',\n)` and a raw `r'/v1/c'` are **not** caught (Issue 3).<br>- **Repo search:** every retrofit annotation is relative (the exemplar plus 3 in `spike/retrofit_api`). Leading-slash `dio.get('/v1/…')` calls exist only in tests (`boot_test`, `harness_test`, `provider_contract_test`), and Dio's `//` collapse keeps them working; all are green. No hand-built URL concatenates `apiBaseUrl` | **PASS** |
| T-0034-AC5 | `tool/checks/T-0034-AC5_no_workaround_markers.sh`; the T-0032 suites and checks | **Yes.**<br>- **Markers:** PASS on HEAD ([report](verifier/T-0034-AC5_no_workaround_markers.md)). On **origin/main's exemplar** (my own `git archive` extract) it FAILS with 14 hits of 9 of the 10 marker kinds (the "word workaround" marker has no hit there) ([report](verifier/T-0034-AC5_negative_control_main_exemplar.md)). My grep finds no `F-0031`, `FlowScope`, `copyWith: false` or leading-slash path in `feature/`.<br>- **T-0032 tests:** `bdd_test` (16 JUnit test cases, 0 failures), `golden_test`, `contract_test`, `architecture_test` and `flow_scope_test` are green uncached.<br>- **Diff of the T-0032 test files against origin/main:** only `characters_list_env.dart` changes behaviour (the hook). `flow_scope_test.dart` is also in the diff, but is **token-identical apart from commas and whitespace** (checked by normalising both versions). Its assertions are unchanged, but it is an unneeded reformat (Issue 4). No `.feature` file, step file or golden changed.<br>- **Checks:** `T-0032-AC6_cutoff.sh` PASS (no aggregate miss; no retrofit, combine or json spawn), `T-0032-AC6_generated_not_committed.sh` PASS, `T-0032-AC6_overlay_tools.sh` PASS, byte identity 11/11.<br>- **Gates:** all green, as listed above | **PASS** |
| T-0034-AC6 | `flow_kit_test` "T-0034-AC6 flowStateOf reads the flow state through the controller", "… fails on another state type and outside a flow"; `characters_list_env.dart` `charactersFlowState` | **Yes.** The hook reads the controller's state, including an in-place update after `controller.update`, and `flowStateOf<dynamic>` returns the same instance.<br>- A wrong type throws a `StateError` that names both types. Outside a flow it throws a `FlutterError`. M8 (drop the type check) fails `flow_kit_test`. P4: in nested flows it returns the innermost flow's state.<br>- **Grep:** no `_LivePage`, `as dynamic)`, `runtimeType}' ==` or `_FeatureFlowState` remains outside `mc_feature_flow/lib`. The BDD step reads only the feature's own state dynamically (`flowStateOf<dynamic>`, accepted by the TL) | **PASS** |

**AC IDs in JUnit names** (fresh `test.xml`): AC1 ×2, AC2 ×3, AC3 ×3, AC4 ×6 (3 in `mc_config`, 3 in `mc_api_client`), AC6 ×2. AC5 is covered by the check scripts named `T-0034-AC5_*`, as with T-0032-AC7's precedent. AC4 also has its script.

## Mutations and probes (mine)
Driver: [mutations.py](verifier/mutations.py). Log: [mutations.log](verifier/mutations.log). Probes: [verifier_probe_test.dart](verifier/verifier_probe_test.dart), run as a temporary `flutter_test` target in `mc_feature_flow` and then removed; output in [probes.log](verifier/probes.log). Every file was restored after each run, and `git status` was clean afterwards apart from this evidence.

| ID | Mutation | Result |
|---|---|---|
| M1 | `di` listens again (`FlowScope.of`) | **Killed:** `flow_kit_test` (3 of 7), `bdd_test` |
| M2 | `debugResolveAll` listens again | Survives. This is an equivalent mutant in practice: it is called from test bodies, where listening is legal |
| M3 | `provide:` runs after `flowInitializer` | **Survives** every committed test (`flow_kit_test`, `bdd_test`, `flow_scope_test`). My P1 kills it (Issue 2) |
| M5 | `provide:` ignored | **Killed:** `flow_kit_test`, `bdd_test` |
| M6 | core and Flutter delegates not appended | **Killed:** `flow_kit_test`, `bdd_test` |
| M7 | feature delegates dropped | **Killed:** `flow_kit_test`, `bdd_test` |
| M8 | `flowStateOf` without its type check (a bare cast) | **Killed:** `flow_kit_test` |
| M10 | barrel without `$PagedStateCopyWith` | **Killed** (build): `copywith_barrel_test`, `bdd_test` |
| M11 | `fromJson` does not normalise | **Killed:** `app_config_test`, `boot_test`, `mini_client:app_test` |
| M12 | `createApiDio` without its assert | **Killed:** `api_client_test` |
| M13 | `withTrailingSlash` always appends (`//`) | **Killed:** `app_config_test` |
| M14 | exemplar back to `'/v1/characters'` | Survives the tests, by design (Dio collapses `//`). **Caught by the AC4 script** ([report](verifier/T-0034-AC4_plant_exemplar_leading_slash.md)) |
| M15 | exemplar path `'v2/characters'` | **Killed:** `bdd_test` (the traffic assertions) |

| Probe | What it shows |
|---|---|
| P1 | An initializer that eagerly resolves the `provide:`d instance works with the shipped order, and fails with the order swapped |
| P2 | After dispose, the provided instance can't be reached through a stale context, a captured container or the hook |
| P3 | A host that already installs the Flutter and core delegates gets duplicates in the flow's merged list, and a host-provided `MaterialLocalizations` override is shadowed inside the flow |
| P4 | An outer flow's `provide:` is not visible in an inner flow, and the hook returns the innermost state |

## New dependency edges
`mc_feature_flow` gains `mc_l10n_core` and `get_it` (pubspec and BUILD `_DEPS`).
- `mc_l10n_core` depends only on `flutter`, `flutter_localizations` and `intl`.
- Nothing among `mc_feature_flow`'s dependencies (`mc_bloc_kit`, `mc_di`, `mc_ds_feedback`, `mc_monitoring`) depends on `mc_feature_flow` or reaches it, so there is **no cycle**.
- The new edges are utility → utility and utility → pub, as ADR-0007's layering allows. `mc_arch_check` and the lint build agree.

## Conformance with plan 01 §3.3
The workaround shapes are gone and now match the plan:
- `create: (context) => context.di<CharactersListBloc>()`, and `context.di<CharacterPreviewBloc>(parameter: character)`
- `provide: (scope) => scope.registerSingleton<CharactersListNavigator>(navigator)`
- `localizationsDelegates: const [CharactersListL10n.delegate]`
- `flowInitializer: const CharactersListDIInitializer()`
- a bare `@freezed` bloc state
- `@GET('v1/characters')`

The divergences that remain are all from before T-0034 and none is a workaround. They are reported for the plan text and the bricks:
1. **Kit API names.** The plan has `FeatureFlow<S, R>` with `imports:`, `name:` and `FlowPage`. The kit (T-0022) has `FeatureFlow<S>` with `rootImports:` and `McFlowPage`, and no `name:`.
2. **Flow state.** The plan's `previewId` and `CharacterPreviewPage(characterId:)` are `preview: Character?` and `CharacterPreviewPage(character:)` here (TL decision, F-0031 B10). `FeatureFlow` is also keyed by `initialTeamId`.
3. **Bloc state.** The plan's `success(PagedSlice<Character>)` and `failure(ApiFailure failure)` are `success(PagedState<Character>)` and `failure(ApiFailure error, {StackTrace? stackTrace})` here (F-0031 B5).
4. **API return type.** The plan's `ApiResponse<ApiPage<…>>` is `ApiPage<…>` here (TL decision 4). The plan text still shows `ApiResponse`; that is P-067, the TL's.
5. **Page content.** The page content wraps a `Scaffold` and app bar, and reads its l10n in `build`. The plan's content is a bare `BlocBuilder`.

## Test-integrity audit
- **Tests deleted, skipped or weakened: none.**
  - The removed `expect` lines are the URL literals in `app_config_test`, `api_client_test` and `boot_test:278`. They now expect the normalised slash, which is a behaviour change (TL decision 3, and the TL approved the `boot_test` line).
  - In `api_client_test`, the T-0023-AC4 inputs gained the slash, because `createApiDio` now asserts it. The checks themselves (override beats config, config feeds Dio) are unchanged.
  - The removed `mcTestWidgets(` and `expect` lines in `flow_scope_test.dart` are re-added identically by the reformat.
  - `charactersFlowState` still fails when no flow is open, since the hook throws outside a flow.
- **Lint suppressions added: none.** There is no new `// ignore:`, `skip:` or `@Skip` in the diff.
- **Golden files updated: none.**
- **Unrelated changes:** format-only reflows in `flow_scope_test.dart`, `api_client_test.dart:12-13` and `characters_list_env.dart:95-96` (Issue 4). Nothing else outside the task's scope. `boot_test.dart:278` is TL-approved.

## Issues found
1. **(minor) The flow's delegates shadow the host's, and the merged list has duplicates.** `utility/mc_feature_flow/lib/src/feature_flow.dart:238-241`. `Localizations.override` inserts `[...feature, ...mcLocalizationsDelegates]` *before* the host's delegates.
   - When the host already installs them, the list holds each Flutter and core delegate 2 or 3 times. Each type is still loaded once, because the first one wins.
   - A host's own override of `MaterialLocalizations`, `CupertinoLocalizations`, `WidgetsLocalizations` or the core strings is silently replaced inside every flow.
   - Repro: probe P3 (a host with a custom `MaterialLocalizations`; inside the flow, `okButtonLabel` is `OK`).
   - Suggested fix: put only the feature's delegates in front, and the `mc` delegates *after* the parent's. For example, build `Localizations(locale: …, delegates: [...feature, ...parentDelegates, ...mcLocalizationsDelegates])`, or append only the types the parent lacks.
   - This is not a regression: the T-0032 workaround did the same. No host customises these today.
2. **(minor) The `provide:` → `flowInitializer` order is documented but not tested.** It is stated in `feature_flow.dart:36-37` and `:62` and in F-0033 fact 2, and implemented at `:169-171`.
   - M3 (swap the order) survives every committed test. P1 kills it.
   - Add a `flow_kit_test` case whose initializer eagerly resolves the provided instance. This matters for an `@singleton` that needs the navigator.
3. **(minor) The relative-path scan misses some shapes and runs in no gate.** `tool/checks/T-0034-AC4_relative_paths.sh:13-16`.
   - It greps single lines, so it misses `@GET(\n  '/v1/…',\n)`, the shape `dart format` produces for a long path, and raw strings (`@GET(r'/v1/c')`). Repro: [plant report](verifier/T-0034-AC4_plant_multiline_raw_doublequote.md).
   - It is not wired into `test //...` or any gate, so it flags only when someone runs it. That fits the TL's "script for now", but the follow-up (F-0033: `mcgen check`) should be in `pending-work.md`.
4. **(minor) Unneeded format reflows in three test files.**
   - `feature/characters/characters_list/test/flow_scope_test.dart` (T-0032's), `utility/mc_api_client/test/api_client_test.dart:12-13` and `characters_list_env.dart:95-96` are rewritten in the collapsed style.
   - They are token-identical apart from commas. origin/main's `flow_scope_test.dart` passes the format gate as it is, so the rewrite was not needed. It looks like the F-0033 fact 7 symptom (format run before `pub get`).
   - The brief allows only the hook change in the T-0032 test files. I'd revert these hunks to keep the exemplar's history clean.
5. **(minor) Small test gaps in the kit.**
   - The hook's "scope has no controller" branch (`utility/mc_feature_flow/lib/testing.dart:17`) is not covered.
   - `FlowScope.of`'s throw (`flow_context.dart:34`) is not covered either.
   - The de half of the l10n test asserts only the feature string (`flow_kit_test.dart:263`, `textContaining('Hallo / ')`), not the German core string.
   - The package is at 97.8 %, so the gate holds.
6. **(nit) Base URL edge handling.**
   - `withTrailingSlash` (`utility/mc_config/lib/src/app_config.dart:23`) becomes public API through the barrel, with no direct test.
   - `createApiDio` asserts but doesn't normalise, and `MockBackend.createDio(baseUrl:)` does neither. In a release build, an explicit slashless `baseUrl` would still fuse host and path. Only the JSON path is normalised.
7. **(nit) Fragile lookups and ordering in the exemplar's test setup.**
   - `charactersFlowState` finds the first `Scaffold` (`characters_list_env.dart:51-53`). Finding the grid key or any flow page would be less coupled to page layout.
   - `//utility/mc_feature_flow` was inserted out of alphabetical order in `characters_list/BUILD.bazel:256`.

## Notes for the Tech Lead
- **The task Outcome is stale.** It says `test //...` passes 76 of 77, but it is 77/77 at 8d7599c.
- **T-0033's branch** still has `boot_test.dart:273` with the old expectation, and the old exemplar (`FlowScope.of`, `'/v1/characters'`). Whichever merges second will hit textual conflicts in `characters_list` and `boot_test`, and must take T-0034's side.
- **Bazel's shared disk cache** answered the first plain `test //...` (0 of 77 executed). Only the `--nocache_test_results` runs above count.

## Re-verification at 318189f

- **Commit verified:** `318189f`, the engineer's fix round on top of my `f97e3dd`, as a detached checkout in my own worktree.
- **Bazel:** the same output base, `/tmp/mc-ob-T-0034-verifier`. I ran `fvm flutter pub get --offline` before `dart format`.
- **Evidence:** [`verifier/r2/`](verifier/r2/).
- **Verdict: PASS.**
  - Round-1 issues 1 to 7 are all resolved.
  - The new back button and card height work as intended, and their tests catch every mutation I tried.
  - One new minor issue (R2-1) and three nits (R2-2), none blocking.

### Gates
| Gate | Result |
|---|---|
| `test --nocache_test_results //...` (covers every touched package uncached) | **Executed 77 out of 77 tests: 77 tests pass** |
| `build --config=lint //...` | exit 0 |
| `mc_arch_check` | OK. **My negative control:** importing `package:mc_feature_flow/testing.dart` from `characters_list_flow.dart` gives exit 1, `[test-only] … imports package:mc_feature_flow/testing.dart outside test/` ([log](verifier/r2/mc_arch_check_negative_control.log)). Reverted. The feature's own `test/` import of the hook stays allowed |
| `rules_fork.sh check` | exit 0 (3 patches on pin `e7163aab8f91`; the flutter queue is empty) |
| Format | 371 files, 0 changed, exit 0 |
| `l10n_check` | OK |
| Coverage, own parser ([coverage.txt](verifier/r2/coverage.txt)) | characters_list 156/156 = 100 %; mc_feature_flow 142/143 = **99.3 %** (up from 97.8; only `feature_flow.dart:213` is missed); mc_paging 100 %; mc_config 100 %; mc_api_client 98.5 %; mc_mocked_backend 93.9 %; **mc_ds_cards 62/62 = 100 %**; **mc_arch_check 173/176 = 98.3 %** (the new rule's lines are covered); mc_test_utils 87.0 % (exempt, unchanged) |
| T-0032 byte identity | **11 of 11 EQUAL**, with build_runner run fresh ("wrote 8 outputs", then "wrote 5 outputs") ([report](verifier/r2/T-0032-AC6_matches_build_runner.md)) |
| T-0032 cutoff / not-committed / overlay tools | PASS / PASS / PASS |
| T-0034-AC4 scan / T-0034-AC5 markers | PASS / PASS. The marker check now reports "every marker tripped" for its one-sample-per-marker control |

### The coordinator's checklist
| # | Check | Result |
|---|---|---|
| 1 | Base URL in release | **PASS.**<br>- `grep assert` finds no assert left in `app_config.dart`, `api_dio.dart` or `backend.dart`.<br>- **Probe** ([source](verifier/r2/verifier_release_probe.dart), [output](verifier/r2/release_probe.log)): `fvm dart run --no-enable-asserts` (the probe confirms `asserts enabled: false`). The `AppConfig` constructor, `AppConfig.parse`, `createApiDio` and `MockBackend.createDio` all turn `https://api.test` into `https://api.test/`, and the requests through both Dios land on `/v1/characters`.<br>- `withTrailingSlash` has a direct test: one slash only, and the `v2` and empty cases.<br>- Mutations: B1 (identity) is killed by `app_config_test`, `api_client_test` and `boot_test`; B2 (`createDio` doesn't normalise) is killed by `mocked_backend_test` |
| 2 | Host delegates | **PASS.**<br>- **Re-run of P3:** inside the flow, the host's override reads **`CUSTOM-OK`**. The flow added no core or Flutter delegate the host already had. The only duplicate left is the host's own (MaterialApp's default Widgets delegate).<br>- **P5:** a bare `MaterialApp` gets `Retry` from the core strings inside the flow.<br>- Committed tests cover both. Mutation D1 (add all the core and Flutter delegates again) is killed by `flow_kit_test`. D2 (add none) is killed by `flow_kit_test` and `bdd_test` |
| 3 | `provide:` order | **PASS.** My swap mutation M3 now fails `flow_kit_test` ("provide: is registered before flowInitializer runs"). In round 1 it survived |
| 4 | Tree shape | **PASS.** The test goes from empty delegates to non-empty and back, with a pushed page. That page's `State` is created once, and the flow state is kept. Mutation T1 (wrap only when the list is non-empty, the old shape) is killed. The test uses a stateful probe page in place of a bloc; that is equivalent, because a remount would recreate both |
| 5 | Back button | **PASS, with R2-1.**<br>- Tests: shown when the flow is pushed, and tapping it pops the flow; absent at the root; an inner page keeps `AppBar`'s automatic back, which pops only that page.<br>- Mutations L1 (always null), L2 (ignore the inner navigator), L3 (pop the inner navigator) and L4 (ignore `outer.canPop()`) are each killed by `flow_kit_test`.<br>- **Generic shape:** a kit-level helper that pops the flow's *outer* navigator through `maybePop` (so `PopScope` is respected), and returns null elsewhere so `AppBar`'s own back stays, is the right concept for every generated feature. But it is computed in the caller's `build` from `inner.canPop()`, which nothing re-evaluates (R2-1) |
| 6 | Card height | **PASS.**<br>- `hasSubtitle` defaults to `true`, and the plain `heightFor(...)` equals the explicit default (test).<br>- `git diff origin/main` lists **one golden: `characters_list_loaded.png`**, plus the before/after copies in the engineer's evidence. I checked that "before" is byte-identical to main's golden and "after" to the committed one.<br>- **Looking at both images:** same layout and art. After the change, each card ends just below the title's two-line slot, with no empty subtitle line, so each row is about 18 px shorter: the third row starts at y≈652 instead of y≈688. Nothing is clipped or overflowing.<br>- The new card test pumps a long two-line title at scales 1 and 2 with `hasSubtitle: false` and gets no exception. The T-0031 clipping test (`paged_grid_test` "a card title is not clipped in its cell") still passes.<br>- Mutations: H1 (default `false`) fails `card_test`, the DS goldens (`mc_ds_cards`, `mc_ds_lists`) and `paged_grid_test`. H2 (drop a title line as well) fails `card_test` (overflow) and the feature golden. H3 (the exemplar back on the default height) fails the feature golden |
| 7 | Items 7–14 | **PASS.**<br>- **Grid anchor:** `charactersFlowState` finds `charactersGridKey` with `findsOneWidget`.<br>- **Marker control:** it plants one sample per marker and requires each marker name to hit, and "every marker tripped".<br>- **Arch rule:** see Gates.<br>- **Python scan:** my own plant in `app/` holds a multi-line `@GET(\n '/v1/…',\n)`, a double-quoted `@POST("/v1/b")`, a raw `@GET(r'/v1/c')`, a multi-line raw `@PUT(\n r"/v1/d")` and a relative `@GET('v1/ok')`. All four bad paths are reported, the relative one is not, and the check FAILS ([report](verifier/r2/T-0034-AC4_my_plants.md)). Its built-in controls pass.<br>- **New tests:** the hook's no-controller branch, `FlowScope.of` outside a flow, and the German `Erneut versuchen`.<br>- **Formatting reverts:** `flow_scope_test.dart` is byte-identical to `origin/main`. `characters_list_env.dart` differs only by the hook import and the lookup. `api_client_test.dart` differs only by the URL literals and the T-0034-AC4 tests. The BUILD dep is sorted.<br>- **`provide:` read once:** this is documented in `characters_list_flow.dart`'s doc comment.<br>- **Outcome:** now 77/77 and lists the fix round. F-0033 facts 3, 5, 7 and 8 are updated |
| 8 | Sample of earlier mutations | M1 (listening `di`): killed by `flow_kit_test` and `bdd_test`. M10 (barrel): `copywith_barrel_test` FAILS TO BUILD. M15 (`v2`): killed by `bdd_test`. Every mutation in [mutations.log](verifier/r2/mutations.log) (16) is killed |

### Test integrity (fix round)
- **Two tests changed behaviour, as the fix requested; neither is weakened.**
  - `api_client_test` "…a base URL without a trailing slash is rejected" became "…is normalised", and now also checks the request path.
  - `app_config_test` "…the constructor asserts…" became "…normalises too, with no assert".
- **The two `mcTestWidgets(` lines removed in `flow_scope_test.dart`** are the reverse of the round-1 reformat, back to `origin/main`'s bytes.
- **No new `// ignore:` or `skip:`.** The only golden change is `characters_list_loaded.png`, with before and after attached.

### Issues found (round 2)
- **R2-1 (minor) `flowLeading()` can lose the root page's back button.** `utility/mc_feature_flow/lib/src/flow_context.dart:79-89`.
  - **The cause:** the decision is made once, in the caller's `build`, from `Navigator.maybeOf(this).canPop()`, and it registers no dependency.
  - **The trigger:** a const root page (the exemplar's shape) rebuilds while an inner page is on top. In the exemplar that is a locale change while the preview is open, because `_CharactersListPageContent` depends on `CharactersListL10n.of`. It then gets `null`, and nothing rebuilds it after the pop.
  - **Probe P6** ([probes.log](verifier/r2/probes.log)): back buttons on the root page went from 1 before to 0 after.
  - **Suggested fix:** a const widget that decides in its own `build` with `ModalRoute.of(context)?.isFirst`. That registers a dependency, so it rebuilds when routes change, and it also gives the bricks one shape: `leading: const McFlowBackButton()`.
- **R2-2 (nit) Stale comments.**
  - `utility/mc_feature_flow/lib/src/feature_flow.dart:66` and the last sentence of F-0033 fact 3 still say "Empty: the flow leaves `Localizations` as the host set it". Now the flow is always wrapped and adds the missing core and Flutter delegates even with an empty list; the bare-host test shows it.
  - `utility/mc_api_client/test/api_client_test.dart:328-329` still says the control is "what the assertion above prevents", but there is no assertion any more.
