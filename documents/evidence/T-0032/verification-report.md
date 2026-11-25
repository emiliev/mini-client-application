# Verification report: T-0032 `characters_list` exemplar feature

- **Verifier:** crew: Verifier (a fresh agent; not the implementer)
- **Date:** 2026-11-25
- **Branch / commit verified:** `fleet/T-0032-characters-list` @ **`c3a5e82`**, a detached checkout in the Verifier's own worktree
- **Simulator:** none. This is a package-level task: widget, BDD and golden tests only. The app wiring and the simulator journey belong to T-0033.
- **Bazel:** `tool/bazelw --output_base=/tmp/mc-ob-T-0032-verifier …`, a new output base. The shared disk cache is still used, because `.bazelrc` sets it, so every test ran with `--nocache_test_results`. The server was shut down at the end.
- **Current verdict: PASS at `1d5e74a`.** See "Re-verification at 1d5e74a" at the end. All seven ACs pass; Issues 1 to 4 are resolved; three new minor notes, none blocking.
- **Round-1 verdict at `c3a5e82`: FAIL.**
  - AC1, AC2, AC4, AC5, AC6 and AC7 pass.
  - **AC3 fails on test strength.** The implementation is right: the preview is a flow page built from `previewId`. But the scenarios cannot tell that apart from a preview pushed imperatively onto the flow's navigator, so the AC's clause "and the flow state has `previewId`" is not proven. The TL's "preview pushed as a route" mutation **survives** when the push goes to the flow's navigator (V4a). It is killed only when the push goes to the root navigator (V4b).
  - The fix is a one-line assertion, already proven by a probe (Issue 1).
  - Three further findings are minor.

My evidence is in [`verifier/`](verifier/). Plain-text links are given relative to this file.

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| All tests, uncached | `test --nocache_test_results //...` | **75/75 PASSED**, exit 0, all 75 executed in the sandbox ([gate-test.log](verifier/gate-test.log)). T-0032 targets: `:bdd_test` (15 cases), `:golden_test` (4), `:flow_scope_test` (2), `:contract_test` (4), `:architecture_test` (2), `//utility/mc_api_client:api_page_test`, `//utility/mc_fixtures_characters:fixture_sets_test`, `//tool/l10n_check:workspace_gate_test`, `//utility/mc_test_utils:init_flow_test` |
| Lint | `build --config=lint //...` | exit 0 |
| Arch | `run //tool/mc_arch_check:bin` | `mc_arch_check: OK` |
| Rules fork | `tool/rules_fork.sh check` | `ai_rules_dart: 3 patch(es) apply strictly on pin e7163aab8f91`; `ai_rules_flutter: queue empty, OK` |
| Format | `fvm flutter pub get --enforce-lockfile`, then `fvm dart format --output=none --set-exit-if-changed feature utility tool/l10n_check tool/mc_arch_check spike app` | 359 files, 0 changed, exit 0. `pubspec.lock` unchanged. (Without `pub get` first, the `mc_analysis` include does not resolve and format reports 20 false changes. The root analysis options need the package config.) |
| l10n | `run //tool/l10n_check:bin` | `l10n_check: OK` |
| Coverage | `coverage --nocache_test_results //feature/characters/characters_list/...`, then my own union parser ([coverage_union.py](verifier/coverage_union.py)) | **160/161 = 99.4 %** of hand-written `lib/` ([coverage.txt](verifier/coverage.txt)). The one missed line is `characters_list_repository.dart:41`, the `StateError` for a character the flow never loaded. The 7 files absent from every report have no executable lines: the barrel, declarations, the const root-import list, and the state `part`. This equals the engineer's figure |
| Lock | `git diff origin/main...HEAD -- pubspec.lock` | Only additions: flutter_bloc **9.1.1** (plan 03's pin), provider 6.1.5+1, nested 1.0.0, mocktail 1.0.5. Nothing moved. `MODULE.bazel.lock` adds only those 4 `pub_deps` repos and the lock hash. `pub get --enforce-lockfile` is clean |

## Acceptance criteria
| AC | Mapped test(s) | Does the test really assert the AC? | Result |
|---|---|---|---|
| T-0032-AC1 | `:bdd_test` "The first page lists 30 characters in name order [T-0032-AC1]"; `:golden_test` "T-0032-AC1 golden…"; `api_page_test`, `fixture_sets_test` | **Yes.** The step counts `SliverGrid` children inside the grid's key, so it is not vacuous: it counts items, not widgets of any type. It walks the grid with real drags. Each `McMediaCard` must match the fixture's name-ordered record, and each `Image` must be the bundled asset of its own thumbnail. The request is `offset=0&limit=30`. Mutations V1 (limit 20), V2a/V2b/V2c (three kinds of wrong sort) and V10 (wrong art) are all killed. V2c sorts the fixture universe by id, the one place where backend and expectation share code. It is killed by the BDD and by 3 fixture-package tests (`T-0018-AC6` "sorted", `T-0018-AC7` snapshot), so the shared expectation is independently pinned | **PASS** |
| T-0032-AC2 | `:bdd_test` Outline "A failed first page explains the problem and retries" × 4 failure kinds; "A failed second page keeps the loaded characters and offers Retry"; golden | **Yes.** The title and the kind-specific copy show. `I tap {'Retry'}` requires exactly one hit-testable Retry. After recovery the first character shows and the error is gone. On page 2: 30 items kept, footer copy plus Retry, and Retry gives 60. V9 (Retry ignored once items exist) is killed, as are the engineer's M5, M6 and M7 | **PASS** |
| T-0032-AC3 | `:bdd_test` "Tapping a character opens its preview inside the flow", "The full profile hands over to the app exactly once", "Going back from the preview keeps the list where I left it"; golden | **Partly.**<br>Strong:<br>- `verify(...openCharacter(id)).called(1)` plus `verifyNoMoreInteractions` (V3, called twice, is killed).<br>- The edge swipe is real. My control starts the same drag at x = 150 instead of x = 2, the preview stays, and the scenario fails.<br>- The exact scroll offset is compared, with 30 items and 1 request (V8 is killed).<br>- A push onto the root navigator is caught (V4b).<br>**Weak:** the "inside the flow / flow state has `previewId`" check reads only `route.settings.name == 'preview'`, `settings.arguments == CharacterId` and "not the root navigator". An imperative `Navigator.of(context).push(MaterialPageRoute(settings: RouteSettings(name: 'preview', arguments: id)))` from the tile, with the flow state never touched, **passes all 15 scenarios and the goldens (V4a)** | **FAIL** (Issue 1) |
| T-0032-AC4 | `:bdd_test` "In German …" and "The pseudo-locale renders … without overflow" (`@l10n`); `workspace_gate_test` "T-0032-AC4 …"; `init_flow_test` "T-0032-AC4 …" | **Yes.**<br>- Removing the German title key (V6a) or the button key (V6b) fails both the BDD scenario and the l10n gate.<br>- English text in the German ARB (V6c) fails the BDD.<br>- `nothing overflows` takes the tester's pending exception. An overflow would fail the test anyway, so the step cannot pass vacuously.<br>- `l10n_check` covers the package through the `:arbs` filegroup | **PASS** |
| T-0032-AC5 | `:bdd_test` "Scrolling to the end of the first page loads the second once" and "At the last page no further page is requested" | **Yes.** Real `tester.drag` drags. `offset=30&limit=30` is requested exactly once, with 2 requests in all and 60 items. On `characters.paged_45`: 45 items, 2 requests, still 2 after another scroll to the end.<br>- **De-dup:** the guard against duplicate page-2 requests has two layers, the controller's `_inFlight` and the grid's latch plus `isLoadingMore`. Each layer alone survives removal (V5a, V5b), because the other still holds. Removing both (V5c) is killed: 2 page-2 requests, and 75 items where 45 were expected.<br>- **End guard:** the same pattern holds (V7a and V7b survive, V7c is killed: 3 requests where 2 were expected). This is defence in depth, and the scenarios assert the outcome, so I accept it.<br>- V5d (the bloc fires `loadMore` twice) is an equivalent mutant: the controller ignores the second call | **PASS** |
| T-0032-AC6 | `:architecture_test` (2), `:flow_scope_test` (2), `:contract_test` (4); `mc_arch_check`; `tool/checks/T-0032-AC6_*.sh` | **Yes**, see "AC6 in detail" below | **PASS** |
| T-0032-AC7 | the gates above | Every gate is green. Coverage is 99.4 % by my own parser. Every behavioural AC carries its tag in a JUnit name (list below). No test or check is named `T-0032-AC7` (Issue 4, minor; T-0031's gates AC set the same precedent) | **PASS** |

JUnit names carrying the IDs (from `test.xml`): AC1 ×2, AC2 ×6, AC3 ×4, AC4 ×4, AC5 ×2, AC6 ×8 plus the 3 check scripts. Two BDD scenarios and one golden carry no tag on purpose (empty catalogue, pull to refresh). No AC asks for them.

### AC6 in detail
| Check | Result |
|---|---|
| `mc_arch_check` | OK. **My negative control:** exporting `CharactersListBloc` from the barrel gives exit 1 (`[R4] … barrel exports CharactersListBloc`), and `:architecture_test` FAILS too. Reverted |
| Barrel | Exactly `CharactersListFlow`, `CharactersListNavigator` and `CharacterId` (the navigator's argument), each a `package:` export with `show`, and no `library;` directive |
| No generated file committed | `git ls-files` finds no `.g.dart`, `.freezed.dart`, `.config.dart`, `.injectable.json`, gen-l10n output or `test/feature/*_test.dart` in the repo. Two matches are hand-written `mc_l10n_core` files. `T-0032-AC6_generated_not_committed.sh` PASSES ([report](verifier/T-0032-AC6_generated_not_committed.md)). The new `.gitignore` lines hide no tracked file (`git ls-files -i -c --exclude-standard` lists only 2 older research docs) |
| Byte identity, regenerated by me | `MC_BAZEL_STARTUP=--output_base=… tool/checks/T-0032-AC6_matches_build_runner.sh` gives **11 of 11 EQUAL**. It runs the generalised `spike_reference.sh` and `injectable_reference.sh` with `MC_REF_SRCS_FROM=:_stage`, so build_runner really ran in a fresh overlay. Hashes: API `.g.dart` `36401c9e…`, `.config.dart` `19268573…`, the DTO, domain, flow-state and bloc-state `.freezed.dart`, the DTO `.g.dart`, and 4 shards ([report](verifier/T-0032-AC6_byte_identity.md)). The generalised scripts stay backward-compatible: **T-0014-AC7, T-0027-AC1 and T-0028-AC1 all PASS** |
| Cutoff, body edit | `T-0032-AC6_cutoff.sh` PASSES ([report](verifier/T-0032-AC6_cutoff.md)). Positive controls: the bloc's freezed action and its shard executed. There is no aggregate miss and no retrofit, combine or json spawn. `.config.dart` and the API `.g.dart` are unchanged. The bloc file is not an input of either action (aquery) |
| Cutoff, **signature edits (mine)**: does it re-run when it should? ([script](verifier/signature_edit_controls.sh), [log](verifier/signature_edit_controls.log)) | **A. A new `@Query` parameter on `getCharacters`:** retrofit part and combine re-run (`cacheHit=False`), and the API `.g.dart` changes `36401c9e → ced4cae6`. The aggregate does not run and `.config.dart` is unchanged. That is correct, because the factory signature did not change.<br>**B. A new named constructor parameter on `CharactersListRepository`:** its shard changes, **`DartAggregateCodegen //…:di_config cacheHit=False`**, and `.config.dart` changes `19268573 → 970fd15f`. Retrofit does not re-run. Both edits use a unique token, so no cache could answer |
| R16 | The state's cases `_Loading`, `_Success` and `_Failure` are private, and the page reads them with `state.when`. The only change is freezed 4's `sealed`. `@Freezed(copyWith: false)` is accepted by the TL |
| R30 | `CharacterDto` and `ThumbnailDto` use `@Freezed(fromJson: true, toJson: true)`. The domain `Character` and the flow state have no JSON, so a bare `@freezed` is correct |
| R15 | Every `:_stage` file is Flutter-free (`architecture_test`, plus my grep). The blocs import `package:bloc` and `mc_bloc_kit` |
| R17 | `flow_scope.dart` is hand-written and marked for `mcgen wire`. `flow_scope_test` resolves every registration, and a root without `Monitoring` fails naming `RootImport<Monitoring>` |
| R6 / R7 | There is no `test/unit/`. The BDD, golden and flow-scope tests import only the barrel plus the test env, which re-declares the string keys rather than importing `src/`. Only `test/contract/` imports `src/` |

## Mutations (mine)
Script: [mutations.py](verifier/mutations.py). Log: [mutations.log](verifier/mutations.log). Every file was restored after each run, and `git status` is clean. Analysis output groups were off, so a lint issue cannot be mistaken for a kill. Each kill was confirmed as a failing scenario, never a build failure.

| ID | Mutation (TL list in bold) | Result |
|---|---|---|
| V1 | **limit 20 instead of 30** (`charactersPageSize`) | killed: AC1 and both AC5 scenarios |
| V2a | **wrong sort:** the mapper reverses each page | killed: AC1, AC2 ×4, AC5 |
| V2b | **wrong sort:** the API sends `orderBy=-name` | killed: AC1, AC2, AC5 |
| V2c | **wrong sort** at the source: the fixture universe sorts by id | killed: BDD, `characters_test` and `provider_contract_test` |
| V3 | **`openCharacter` called twice** | killed: "hands over … exactly once" |
| V4a | **preview pushed as a route**, onto the flow's navigator (`name: 'preview'`, `arguments: id`), with the flow state untouched | **SURVIVED** (all 15 BDD cases and 4 goldens pass) → Issue 1 |
| V4b | **preview pushed as a route** onto the root navigator | killed: AC3 ×3, AC4 |
| V5a / V5b | **no de-dup on page 2**, one layer: the controller's `_inFlight` (a), or the grid's latch plus `isLoadingMore` (b) | survived (the other layer holds) |
| V5c | **no de-dup on page 2**, both layers | killed: both AC5 scenarios |
| V5d | the bloc fires `loadMore` twice without awaiting | survived; an equivalent mutant, because the controller drops the second call |
| V6a / V6b | **German ARB key missing → English fallback** (title, or button) | killed: the German scenario **and** `//tool/l10n_check:workspace_gate_test` |
| V6c | the German button holds the English text | killed: the German scenario |
| V7a / V7b | **end guard removed**, one layer (controller, or grid) | survived (the other layer holds) |
| V7c | **end guard removed**, both layers | killed: "At the last page …" (3 requests where 2 were expected) |
| V8 | the list page gets a new key on every build (scroll lost on back) | killed: "Going back …" |
| V9 | Retry is ignored once items exist | killed: "A failed second page …" |
| V10 | every character's art is `000` | killed: AC1, AC3 ×2 |
| control | `I swipe back` starts at x = 150, not at the edge | the "Going back" scenario fails (the preview stays), so the step is a real edge swipe |

## Conformance

### Tide's articles (`documents/research/tide-miniclient/`)
| Rule | Finding |
|---|---|
| The flow is the only entry and its constructor is the contract [tide-nav §3.1] | Yes. `CharactersListFlow({required navigator, initialTeamId})` |
| Internal navigation is flow state; plain models, not unions [tide-nav §3.3] | `CharactersListFlowState(teamId?, previewId?)` is a plain freezed model, and the list bloc calls `_flow.update(copyWith(previewId:))`. Correct, but not pinned by a test (Issue 1) |
| Only blocs call navigators; widgets dispatch events (plan 01 §4.1) | Yes. `openCharacter` is called only in `CharacterPreviewBloc`'s handler. The tile and the button dispatch events |
| `BlocProvider` is the only DI use in UI [tide-core §5.10] | Yes, under the TL-accepted workaround: `FlowScope.of(context).container` is read in `build`, and the lookup happens inside `create`. No other DI call in `presentation/` or the flow |
| Sealed hand-written events with private cases, and the bloc dispatches `load` from its constructor [tide-core §5.8] | Yes |
| Monitoring stays out of business logic [tide-core §5.8] | Yes, through `McBloc`. The failure state `@Implements<McFailureState>()` |
| The DI initializer's boilerplate is verbatim [tide-core §5.9] | Yes. The navigator is registered by a wrapping `McDIInitializer` (TL-accepted workaround for `provide:`) |
| Mock only external dependencies and API responses [tide-test §4.2] | Yes. The navigator is a mocktail mock, and the backend is `mc_mocked_backend` at the transport. The bloc, repository, API, mapper and flow are real |
| Data from outside the implementation [tide-test §4.5] | Expectations come from `mc_fixtures_characters`, never from feature code. The shared-sort risk is covered by the fixture package's own tests (V2c) |
| Repository unwraps the wire model and returns values [tide-core §5.6] | Yes: `Result<Page<Character>, ApiFailure>` through `apiCall`. **Difference:** Tide's repository is a stateless `@injectable`. Here it is a per-flow `@lazySingleton` with a `_loaded` cache, which the preview reads (Issue 3) |

### Plan 01 §3.3 (layout and code shapes)
- **Layout:** it matches plan 01 §3.3, with one gap. `analysis_options.yaml`, which §3.3 lists and §3.1 defines as the one-line include, is missing (Issue 2).
  - Present: the barrel, `di/`, `domain/{api,model,repository}`, `navigator/`, `flow/`, `presentation/{bloc,page,widget}`, `l10n/` (en, de and en_XA), `BUILD.bazel`, `l10n.yaml`, and `test/{feature,feature/step,feature/util,contract,golden}`.
  - Additions: `test/architecture/` and `test/flow_scope_test.dart`. Both are justified (R4/R15, R17).
  - Plan 05 §3.1 shows the goldens as a `.feature` file; they are a Dart test here. That is a small deviation, not a defect.
- **Code shapes:** the plan's code is followed, except where F-0031 B records a run-time gotcha and the TL has accepted the workaround:
  - `context.di`, `provide:` and `localizationsDelegates:`;
  - the leading-slash path;
  - no `ApiResponse`;
  - `copyWith: false`;
  - the `McFailureState` field names;
  - `McFlowPage` instead of `FlowPage`.

  Each workaround is marked in the code. The navigator has only `openCharacter`, as the task asks.
- **Barrel:** see AC6. `CharacterId` is exported because the navigator takes it. That is within R4's "arg types", and the app must see it to implement the navigator.

## Test-integrity audit
- **Tests deleted, skipped or weakened:** none.
  - The only modified tests are `tool/l10n_check/test/workspace_gate_test.dart` and `utility/mc_test_utils/test/init_flow_test.dart`. Both only gained a case.
  - `T-0014-AC7` and `T-0027-AC1` changed only `"$BAZELW"` → `bzw`. Their assertions are unchanged, and both PASS.
  - No `skip:`, `@skip` or `@wip`.
- **Lint suppressions added:** none in hand-written code. The only `// ignore` lines are in gen-l10n output, which `pub get` writes into my worktree; it is git-ignored and not committed.
- **Golden files:** 4 new under `feature/characters/characters_list/test/golden/goldens/`. **No existing golden changed**: `git diff --name-status origin/main...HEAD -- '*.png'` shows only `A` entries.
- **Shared changes (TL-approved, checked for backward compatibility):**
  - `McTestApp` gained `GlobalMaterialLocalizations.delegates`. Every existing widget and golden test still passes.
  - `lib.sh` gained `bzw`, which falls back to plain `bazelw` when `MC_BAZEL_STARTUP` is unset.
  - `l10n_check` gained the gate data plus one test.
- **Unrelated changes:** none.
  - The diff touches the feature, `mc_api_client` (`ApiPage`), `mc_fixtures_characters` (new sets; existing data, scenarios and snapshots unchanged), `mc_test_steps` (new generic steps), the three approved areas, the reference scripts (P-054/P-059), `.gitignore`, the root pubspec and locks, the task file, F-0031 and the engineer's evidence.
  - No index, STATUS or BOARD file is touched.

## Visual acceptance (goldens, 402×874)
| Golden | What is visible | OK? |
|---|---|---|
| `characters_list_loaded.png` | The "Characters" app bar, then a 2-column grid: Amber Alchemist, Amber Artisan, Amber Bard, Amber Beacon, with two more cut off by the viewport. Each card has its own coloured placeholder silhouette (real fixture art) and its name in Inter. Nothing clipped; the space under the name is reserved for the text scale | yes |
| `characters_list_error.png` | App bar, a red alert icon, "Characters could not be loaded", "The server had a problem. Please try again later.", and a red "Retry" button | yes |
| `characters_list_empty.png` | App bar, an inbox icon, "No characters yet" and "New characters will show up here." | yes |
| `character_preview.png` | The iOS back chevron, the title "Amber Alchemist", the portrait-large art at full width, and a full-width red "See full profile" button | yes |

There is no German golden. German is covered by the BDD scenario.

## Issues found
1. **(Major, AC3 test strength; this is why the verdict is FAIL.)** `feature/characters/characters_list/test/feature/step/i_see_the_character_preview_for.dart:23-25` does not prove that the preview is flow state.
   - **Repro:** replace `CharacterTile.onTap` with `Navigator.of(context).push(MaterialPageRoute<void>(settings: RouteSettings(name: 'preview', arguments: character.id), builder: (_) => CharacterPreviewPage(characterId: character.id)))`. Then `bazel test :bdd_test :golden_test` passes. The swipe back also passes, because it pops the pushed route.
   - **Why it matters:** this is the template for about 100 features. A generated feature that navigates imperatively inside its flow, against plan 01 §4.1 and Tide's "a screen of the same feature is flow state", would pass its BDD.
   - **Fix (proven):** add `expect(route.settings, isA<Page<Object?>>(), reason: 'a flow page, not a pushed route');` after line 24. The probe ([probe_v4a.py](verifier/probe_v4a.py)) shows it passes on `c3a5e82` and kills V4a ("Tapping a character…" and "Going back…" fail).
   - **Alternative:** assert the flow state itself, for example through a test hook in `mc_feature_flow`.
2. **(Minor, template conformance.)** `feature/characters/characters_list/analysis_options.yaml` is missing. Plan 01 §3.3 lists it, and §3.1 makes it the one-line `include: package:mc_analysis/analysis_options.yaml`. The root file covers analysis today, so nothing is broken. But generators copy this package, and other packages (for example `mc_paging`) carry the file. Add it, or have the TL drop it from §3.1/§3.3.
3. **(Minor, design note for the template.)** `characters_list_repository.dart:17-41`: the repository is a stateful per-flow `@lazySingleton` cache (`_loaded`). The preview bloc's constructor throws `StateError` (line 41) for an id the list never loaded.
   - That is unreachable today, but a future flow argument (deep link to a preview) or a refresh that drops items would hit it.
   - Tide keeps repositories stateless and puts the selected model in flow state.
   - Either is defensible. The TL should decide which shape the generators copy (pending-work candidate).
4. **(Minor, traceability.)** No test or check name carries `T-0032-AC7`. The gates and coverage are verified here, as for T-0031. A `tool/checks/T-0032-AC7_*.sh`, or naming the coverage gate, would make `tool/trace_acs` complete.

## Notes for the Tech Lead
- Everything else is solid.
  - The 11-file byte identity reproduces exactly.
  - The cutoff works in both directions (body edit: no re-run; signature edits: retrofit or aggregate re-runs as it should).
  - Every TL-named mutation except V4a is killed: by the feature alone, or, for the guards that live in `mc_paging` and `mc_ds_lists`, once both layers are removed.
- The contract tests are tagged `T-0032-AC6`, although AC6 is about architecture and codegen; it is a loose fit, but harmless.
- The feature relies on the backend's default `orderBy=name` and does not send it. That is fine under the contract, and any change would be caught by AC1's scenario.
- Re-verifying a fix for Issue 1 needs only `:bdd_test`, plus `probe_v4a.py`'s V4a half against the fixed step.

## Re-verification at 1d5e74a
- **Commit verified:** `1d5e74a`, a detached head in my own worktree. Since my report (`88a3c99`) it adds 3 WIP commits, the fix commit `55c2654` and a docs-only merge of `origin/main`.
- **Bazel:** `--output_base=/tmp/mc-ob-T-0032-verifier`, shut down at the end.
- **Evidence:** [`verifier/reverify-1d5e74a/`](verifier/reverify-1d5e74a/). Every mutation and probe restored its files, and `git status` was clean after each batch.
- **Verdict: PASS.** All seven ACs pass. Round-1 Issue 1 (major) is fixed and pinned. Issues 2 to 4 are resolved or decided by the TL. Three new minor notes follow, none blocking.

### Gates
| Gate | Result |
|---|---|
| `test --nocache_test_results //...` | **75/75 PASSED**, all executed ([gate-test.log](verifier/reverify-1d5e74a/gate-test.log)). `:bdd_test` has 16 cases (new: "A second tap while the preview slides in keeps the first character [T-0032-AC3]"). `:flow_scope_test` has 3, `harness_test` gains 2 `T-0032-AC2 recover()` cases, and `:architecture_test` has 3 |
| `tool/checks/T-0032-AC7_gates.sh`, which I ran myself | **PASS**: test (T-0032 packages uncached), lint, `mc_arch_check`, `rules_fork.sh check` (3 patches strict), `dart format`, `l10n_check`, coverage ≥ 90 % ([report](verifier/reverify-1d5e74a/T-0032-AC7_gates.md)) |
| Coverage, my own parser over the same `bazel coverage` output | **160/160 = 100 %** ([coverage.txt](verifier/reverify-1d5e74a/coverage.txt)). The repository's unreachable `StateError` is gone. The files absent from every report have no executable lines |
| Byte identity (`T-0032-AC6_matches_build_runner.sh`, build_runner regenerated in fresh overlays) | **11 of 11 EQUAL** ([report](verifier/reverify-1d5e74a/T-0032-AC6_byte_identity.md)). New hashes where the code changed: `.config.dart` `084e4f6f…`, the flow-state `.freezed.dart` `a1375d3d…`, the repository shard `605a4035…` and the preview-bloc shard `b0c8e6b1…`. Unchanged: the API `.g.dart` `36401c9e…`, the DTO files and the bloc state |
| Cutoff (`T-0032-AC6_cutoff.sh`) | **PASS**. Both positive controls executed. No aggregate miss and no retrofit, combine or json spawn. `.config.dart` and the API `.g.dart` are unchanged ([report](verifier/reverify-1d5e74a/T-0032-AC6_cutoff.md)) |
| Generated files not committed | **PASS**, including the new visibility rows ([report](verifier/reverify-1d5e74a/T-0032-AC6_generated_not_committed.md)) |
| Locks | `pubspec.lock`, `MODULE.bazel.lock` and the root `pubspec.yaml` are unchanged since `c3a5e82` |
| Goldens | `git diff c3a5e82..1d5e74a -- '*.png'` is empty, so all 4 are byte-identical to the ones I inspected in round 1. `:golden_test` passes. No file was deleted |

### The 12 fix items
| # | Item | What I did | Result |
|---|---|---|---|
| 1 | **AC3: the preview is flow state** | **R1** (V4a adapted: push a `MaterialPageRoute` named `preview` onto the flow's navigator, with the flow state untouched) is killed: 3 AC3 scenarios fail.<br>**R2** is V4a with the step's new `Page` check deleted, so only the flow-state read is left. It is still killed: the first failure is `Expected: <100486> Actual: <null>, the flow state selects Amber Alchemist`.<br>**R3** (V4b, root navigator) and **R6** (preview page not keyed by the id) are killed.<br>**The flow-state read cannot pass vacuously.** `charactersFlowState` first expects at least one `_LivePage<CharactersListFlowState>` (`findsWidgets`). It then reads `.controller.state`, the flow's `FeatureFlowController` (`feature_flow.dart:203-207`), which is the same object the bloc injects and updates. A renamed internal throws (`NoSuchMethodError` or a failed `findsWidgets`), so it fails loud.<br>`I don't see the character preview` now also expects `preview == null`, so the swipe back really clears the flow state. Reading internals is accepted until T-0034 | **PASS** |
| 2 | **Stateless repository** | `CharactersListRepository` is a `const` stateless `@injectable` with no cache and no `StateError`, and `CharactersListFlowState.preview` is a `Character?`. The flow builds `CharacterPreviewPage(character: state.preview)`, and the page gets its bloc with `flow<CharacterPreviewBloc>(parameter: character)`. The bloc's state is that `@factoryParam Character`, and it no longer depends on the repository (`character_preview_bloc.dart:25-30`). So the preview reads the flow state, not a repository | **PASS** |
| 3 | **Fast second tap** | The guard is at `characters_list_bloc.dart:71-76` (`if (_flow.state.preview == null)`), and the preview page is keyed `ValueKey(character.id)`. **R5** removes the guard, and the new same-frame scenario fails.<br>**My own probe** puts a second tap on Amber Bard (left column, still visible) at 12 % of the slide-in, not in the same frame. With the guard in place (**P1**) and without it (**P2**), the preview stays Amber Alchemist and "See full profile" opens Alchemist. That second tap never reached the list, so the preview route's barrier does take taps during the slide-in, as the engineer says.<br>The only open window is two taps in one frame, and the scenario reproduces exactly that. **I accept it** | **PASS** |
| 4 | **`McBackendHarness.recover()`** | `recover()` switches each harness rule off on the engine (its predicate becomes `mirror.live && …`) and in the mirrors (`_failRules.clear()`), then calls `useScenario(null)`. It does not touch store, latency, counters, traffic or requests.<br>**H1** keeps the mirrors: killed (an unrouted request is not reported). **H2** keeps the engine rule live: killed in `harness_test` and in 5 AC2 BDD scenarios. **H3** goes back to `backend.reset()`: killed ("the store survives").<br>**Meaning of existing tests:** the predicate is now always passed. With an empty query, `queryMatches` is `every` over nothing, which is `true`, the same as the old `null`; the engine uses the predicate only in `matches()`. Against `origin/main`, `mc_test_utils/test/` only gained cases (2 in `harness_test`, 1 in `init_flow_test`). No existing line changed, and all of its targets pass | **PASS** |
| 5 | **AC7 gates check** | My forced miss adds a 20-line function that no test calls to `failure_message.dart`, keeping the default threshold of 90. Result: **FAIL T-0032-AC7-gates**, exit 1, with the coverage row **FAIL** at 160/180 = 88.9 % and every other gate PASS ([report](verifier/reverify-1d5e74a/T-0032-AC7_gates_forced_miss.md)). Reverted | **PASS** |
| 6 | BUILD comment on `analysis_options` | `BUILD.bazel:3`: "No per-package analysis_options.yaml: the root file applies (F-0021)". This matches the TL decision | **PASS** |
| 7 | Team switch | **K7** drops `key: ValueKey(initialTeamId)`, and "T-0032-AC1 a new initialTeamId builds a new flow that lists that team" fails | **PASS** |
| 8 | `.gitignore` scoping | My `git check-ignore -v --no-index` run:<br>**Visible:** `test/feature/x_test.dart`, `test/feature/characters_list_test.dart`, `lib/src/app.config.dart` and a step file.<br>**Ignored:** `lib/src/di/di_initializer.config.dart` (`.gitignore:30`), `*.injectable.json` (`:31`), `.g.dart` (`:25`), `.freezed.dart` (`:26`), and `characters_list_l10n.dart` / `_de.dart` (`:32`, `:33`) | **PASS** (note N1) |
| 9 | Overlay helpers | `T-0032-AC6_overlay_tools.sh` passes over the new scripts. With `MC_OVERLAY_TOOLS` pointing at the `c3a5e82` scripts it **FAILS**: `overlay_deps.py` stops at the blank line (it returns only `b`, losing `dio`), and `add_dep.py` does not add the dev-only `mocktail` ([new](verifier/reverify-1d5e74a/T-0032-AC6_overlay_tools.md), [old](verifier/reverify-1d5e74a/T-0032-AC6_overlay_tools_old_scripts.md)) | **PASS** |
| 10 | l10n gate names a missing German key | The gate test now plants a copy without `charactersListTitle` in `de`. It expects a violation naming the package, `de` and the key. Independently, **V6b** (the real `de` ARB loses the button key) fails `//tool/l10n_check:workspace_gate_test` and the German BDD scenario | **PASS** |
| 11 | Both quote styles | A double-quoted `export "…/characters_list_bloc.dart" show CharactersListBloc;` in the barrel fails both:<br>- `:architecture_test`, because the exports are no longer the 3 allowed ones;<br>- `mc_arch_check`: `[R4] … barrel exports CharactersListBloc`.<br>A double-quoted `import "package:flutter/foundation.dart"` in the navigator fails `:architecture_test` ("… imports Flutter"). Both reverted | **PASS** |
| 12 | Synthetic padding | `CharacterUniverse.synthetic` pads to `max(2, len(count))`. **K12** goes back to `padLeft(2)`, and "T-0032-AC5 a synthetic cast past 99 still pages in name order" fails | **PASS** |

### Sampled round-1 mutations
Script: [mutations.py](verifier/reverify-1d5e74a/mutations.py). Log: [mutations.log](verifier/reverify-1d5e74a/mutations.log). Every one below is still killed by failing scenarios, never by a build failure:
- V1 (limit 20)
- V2b (`orderBy=-name`)
- V3 (`openCharacter` twice)
- V5c (no page-2 de-dup, both layers)
- V6b (German key missing; BDD and l10n gate)
- V7c (no end guard, both layers)
- V8 (list rebuilt on back)
- V10 (wrong art)

### Acceptance criteria at 1d5e74a
| AC | Result |
|---|---|
| T-0032-AC1 | **PASS**. As in round 1, plus the team-key test (item 7) |
| T-0032-AC2 | **PASS**. The `recover()` semantics are pinned (H1 to H3) |
| T-0032-AC3 | **PASS**. The preview is proven to be flow state: R1, R2, R3 and R6 are killed. The double-tap guard is pinned (R5), and my slide-in probe confirms the barrier |
| T-0032-AC4 | **PASS** |
| T-0032-AC5 | **PASS**. Plus the padding fix (K12) |
| T-0032-AC6 | **PASS**. 11/11 EQUAL, the cutoff passes, nothing generated is committed, and both quote styles are handled |
| T-0032-AC7 | **PASS**. `T-0032-AC7_gates.sh` passes, and it fails on a forced coverage miss (this closes round-1 Issue 4) |

### Test-integrity audit (fix round)
- No test deleted, skipped or weakened. No `// ignore:`, `skip:`, `@skip` or `@wip` was added (checked by grepping the `c3a5e82..1d5e74a` diff).
- The removed `expect` lines are rewrites, not removals:
  - in `architecture_test`, regex groups were renumbered for the quote-style capture, and the same assertions remain;
  - in the preview step, the `arguments` check is kept with a hoisted `id`.
- The two changed steps are stronger: Page, flow state and key in one; the flow state cleared in the other.
- `architecture_test` dropped its `dart test` path fallback. It is Bazel-only, as documented.
- No golden changed.

### New notes (minor, none blocking)
- **N1 (minor, docs).** Plan 01 §3.1 (`documents/plan/01-architecture-and-modules.md:192`) still lists `*.config.dart` and `test/feature/*_test.dart`, so it no longer matches the scoped root `.gitignore`. Under an R28 BDD fallback, stock bdd_widget_test writes `test/feature/*_test.dart` into the source tree, and those files would show as untracked. The R28 managed block would need its own pattern. This is TL-owned text.
- **N2 (minor).** `tool/checks/T-0032-AC7_gates.sh` runs `documents/evidence/T-0032/engineer/merge_lcov.py`. A gate script that depends on a file under evidence is fragile; it belongs in `tool/`.
- **N3 (cosmetic).** The gates report's "tests:" line shows the second, cached `test //...` ("Executed 0 out of 75"), not the uncached T-0032 run that precedes it. The gate itself is right.
