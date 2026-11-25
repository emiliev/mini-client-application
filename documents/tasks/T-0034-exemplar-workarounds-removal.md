# T-0034: Remove the `characters_list` exemplar's workarounds (`mc_feature_flow`, `mc_paging`, base URL)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-25 `2d90da9`; Verifier PASS `e955f0d`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0034-exemplar-workarounds` |
| Created | 2026-11-25 |
| Depends on | T-0032 |
| Related | F-0031 (Part A: the `copyWith` barrel; Part B: run-time gotchas in plan 01's canonical code), plan 01 §3.3, R30, P-024 |

## Goal
T-0032 left marked workarounds in `characters_list`, because three kits don't do what plan 01's canonical code assumes. Phase D's bricks will copy the exemplar about a hundred times, so the kits must be fixed and the exemplar changed back to the plan's shape **before** P1-24 (mason bricks).

## TL decisions (2026-11-25, on T-0032's questions)
1. **`mc_feature_flow`:**
   - `context.di` becomes non-listening, so it is safe inside `BlocProvider.create`.
   - `FeatureFlow` gains `provide:` (register flow-scoped instances such as the navigator) and `localizationsDelegates:`, as plan 01 §3.3 assumes.
2. **`mc_paging`:** the barrel also exports `$PagedStateCopyWith`, so a bloc state that holds `PagedState` keeps freezed's default `copyWith`. That is Tide's shape. The exemplar's `@Freezed(copyWith: false)` goes away.
3. **Base URL:** `apiBaseUrl` always ends with `/`, and retrofit paths are relative (`'v1/characters'`), as in plan 01 and retrofit's convention.
   - `mc_config` normalises the value and asserts the trailing slash.
   - A test fails if a leading-slash path is used.
4. **No `ApiResponse<T>` wrapper.** The mocked backend contract has none, so plan 01 §3.3's `ApiResponse<ApiPage<…>>` becomes `ApiPage<…>`. The TL updates the plan text (P-067).
5. **Flow-state test hook:** `mc_feature_flow` exposes a public testing API (e.g. `package:mc_feature_flow/testing.dart` with `flowStateOf<S>(tester or context)`), so BDD steps can assert flow state without reaching into internals. T-0032's preview step reads them dynamically today (F-0031 B11).
6. **mocktail** is in the lock now. Moving F-0024's hand-written `MockMonitoring` to mocktail is optional and out of scope.

## Scope
- **In:** decisions 1–3 and 5, implemented in `mc_feature_flow`, `mc_paging` and `mc_config`/`mc_api_client`. Remove the marked workarounds in `feature/characters/characters_list` so it matches plan 01 §3.3's code.
- **Out:** `mcgen wire`, and any changes to the exemplar beyond removing the workarounds.

## Acceptance criteria
- **T-0034-AC1:** A widget test shows that `context.di<T>()` inside `BlocProvider.create` doesn't throw and doesn't register a dependency on the inherited scope. A rebuild of the scope doesn't recreate the bloc.
- **T-0034-AC2:** A `FeatureFlow` with `provide:` makes the provided instance resolvable inside the flow, and nowhere outside it. With `localizationsDelegates:`, the flow's strings resolve for `en` and `de`. Both are tested in `mc_feature_flow`.
- **T-0034-AC3:** A freezed bloc state holding `PagedState<T>` compiles with the default `copyWith`, including the deep `copyWith`, in a test package. The generated outputs are still byte-identical to build_runner's (`spike_reference.sh`).
- **T-0034-AC4:** `apiBaseUrl` without a trailing slash is normalised. A retrofit path with a leading slash is rejected or flagged by a test or lint. The exemplar uses `'v1/characters'`, and its requests still hit `/v1/characters`.
- **T-0034-AC5:** `characters_list` has no workaround markers left (grep for the T-0032 marker comments). All T-0032 ACs still pass unchanged, and the T-0032 byte-identity and cutoff checks still pass. Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format, coverage ≥ 90 % for every touched package.
- **T-0034-AC6:** The T-0032 preview step uses the public flow-state test hook, with no dynamic access to `mc_feature_flow` internals; the hook is tested in `mc_feature_flow`.

## Log
- 2026-11-25: Created (TL) from T-0032's handoff questions; dispatched to a Sonnet engineer after T-0032 merged.
- 2026-11-25: Engineer started on `fleet/T-0034-exemplar-workarounds` from `origin/main` 0395230.
- 2026-11-25: Handoff. See Outcome.

## Outcome
Kits fixed and the exemplar is back to plan 01 §3.3's shape. Details and gotchas: [F-0033](../findings/F-0033-exemplar-kit-fixes.md). Evidence: `documents/evidence/T-0034/engineer/`.

| AC | Test or evidence |
|---|---|
| AC1 | `//utility/mc_feature_flow:flow_kit_test` "T-0034-AC1 …" x2: no throw, bloc created once, a listening control rebuilds on a scope swap while `context.di` does not, and the bloc is kept. With `di` listening again, 3 tests fail (`negative_controls.md`). |
| AC2 | `flow_kit_test` "T-0034-AC2 provide: …" (inside only; a second flow and the root cannot resolve it), "localizationsDelegates … en and de", "without localizationsDelegates the host decides". |
| AC3 | `//utility/mc_paging:copywith_barrel_test` "T-0034-AC3 …" x3 (class, deep `copyWith.page(...)`, union case) over a freezed fixture generated by the Bazel shim. Without the barrel export it fails to compile. `T-0032-AC6_matches_build_runner.sh` 11/11 EQUAL, with the bloc state now holding 3 `$PagedStateCopyWith` references. |
| AC4 | `mc_config:app_config_test` "T-0034-AC4 …" x3 (normalises, keeps, constructor asserts); `mc_api_client:api_client_test` "T-0034-AC4 …" x3 (relative path hits `/v1/characters`, slashless base rejected, control: Dio fuses host and path); `tool/checks/T-0034-AC4_relative_paths.sh` (leading-slash scan with negative controls). The exemplar uses `'v1/characters'`; the BDD run proves the request path. |
| AC5 | `tool/checks/T-0034-AC5_no_workaround_markers.sh` (PASS; origin/main's exemplar FAILS it); T-0032 byte identity, cutoff, not-committed and overlay-tools checks PASS; BDD, flow_scope, contract, golden and architecture tests unchanged and green; `tool/checks/T-0034-AC5_gates.sh`. |
| AC6 | `flow_kit_test` "T-0034-AC6 …" x2 (reads state; wrong-type and outside-a-flow errors); the exemplar's `charactersFlowState` uses `flowStateOf<dynamic>`. |

- **Gates:** lint, `mc_arch_check`, `rules_fork.sh check`, format and `l10n_check` PASS. Coverage: characters_list 100 %, mc_feature_flow 97.8 %, mc_paging 100 %, mc_config 100 %, mc_api_client 98.5 %, mc_mocked_backend 92.5 %. `mc_test_utils` is 87 % (`fixture_assets.dart` is only exercised by feature tests); that was already so on `origin/main`, I changed one line of it (100 %), and the gate script lists it as exempt.
- **`test //...`: 77 of 77 pass.** The one-line expectation in `app/wiring/app_core/test/boot_test.dart:278` (`…invalid/`) was changed by this task's engineer, with the TL's permission (commit `T-0034: Expect the normalised base URL in the boot test`).
- **Test changes (no test deleted, skipped or weakened; no `// ignore:`):**
  - `characters_list_env.dart`: `charactersFlowState` now uses the hook (AC6); the BUILD gains a direct `mc_feature_flow` test dep.
  - `mc_config` `app_config_test` and `mc_api_client` `api_client_test`: URL literals gained the trailing slash because the behaviour changed (TL decision 3).
  - `McTestContainer.config` is `static final`, since `AppConfig`'s constructor can no longer be `const`.
- **Non-test changes outside the named packages:** `mc_mocked_backend` and `mc_test_utils` default URLs, and `tool/bazel/config/{dev,e2e,perf}.json` (trailing slash).
- **Fix round (after the Verifier PASS and the reviews).** Evidence: `fixround_mutations.txt` (10 mutations, each killed by the named tests), `goldens/`, regenerated gates.
  1. The trailing slash is normalised in code, not asserted: `AppConfig` constructor, `createApiDio`, `MockBackend.createDio`. `withTrailingSlash` has a direct test. Tests: T-0034-AC4 in `mc_config`, `mc_api_client`, `mc_mocked_backend`.
  2. The flow no longer shadows host delegates: `Localizations.override` already puts the flow's own delegates first and keeps the host's, so the flow adds a core or Flutter delegate only when the host lacks that type. Test: a host `MaterialLocalizations` override (`CUSTOM-OK`) survives; a bare host still gets the core strings.
  3. `provide:` before `flowInitializer` is pinned by an initializer that resolves the provided instance at once.
  4. The tree shape is stable: the flow is always wrapped in `Localizations.override`. Test: changing the delegates from empty to non-empty and back keeps the pushed page and its state (no remount).
  5. `context.flowLeading()` (in `mc_feature_flow`): a back button for the flow's root page when the outer navigator can pop, which pops the flow; null otherwise, so inner pages keep AppBar's automatic back. `CharactersListPage` uses it. Tests: present when pushed, tap pops the flow, absent at the root, inner page unaffected.
  6. `McMediaCard.heightFor` gained `hasSubtitle` and `titleLines`. I chose `hasSubtitle = true` as the default, so every existing DS caller and golden keeps its height; `characters_list` passes `false`. Goldens changed: only `feature/characters/characters_list/test/golden/goldens/characters_list_loaded.png` (shorter cards; before and after in `goldens/`). No DS golden changed.
  7. The env's flow-state lookup is anchored to `charactersGridKey`.
  8. The AC5 marker script plants one sample per marker and requires every marker to trip (a broken regex now fails it).
  9. `mc_arch_check` rule `test-only`: `package:x/testing.dart` may be imported from `test/` only. Fixture `testing_import`, test `T-0034-AC6 a testing.dart import outside test/ fails`.
  10. `T-0034-AC4_relative_paths.sh` is now a Python scan: multi-line annotations, raw strings, both quote styles, with a control for each (and a relative path must stay quiet).
  11. New tests: the hook's no-controller branch, `FlowScope.of` outside a flow, and the German core string (`Erneut versuchen`) in the en/de test.
  12. The formatting-only hunks in `flow_scope_test.dart`, `api_client_test.dart` and `characters_list_env.dart` are reverted; the BUILD dep is sorted.
  13. I documented that `provide:` is read once per flow instance (the flow is already keyed by `initialTeamId`); the navigator is not part of the key.
- **Open for the TL:** the hook is untyped in the BDD step (`dynamic` over the feature's private state); typing it needs the feature to export the state type for tests. Wiring the relative-path scan into `mcgen check` is a follow-up.

## Merge (TL)
- 2026-11-25: Verifier PASS `f97e3dd`. `/code-review` found that the trailing slash was only asserted (stripped in release); the Verifier found host delegate overrides replaced inside flows and the `provide:` order unpinned; the T-0033 Verifier found the list had no back button when pushed and the card reserved empty subtitle space. Fixed in `318189f` (14 items, 10 proof mutations). TL decisions: `mc_feature_flow` gives a flow's root page an automatic back button (`context.flowLeading()`); `McMediaCard.heightFor(hasSubtitle:, titleLines:)`, with the default kept at `true` so DS goldens are stable. Re-verify PASS `e955f0d` (release probe with asserts off, 16 mutations). The TL merged `--no-ff`; on the merge result `check` passed with 3 patches, 77/77 tests, lint was clean and `mc_arch_check` reported OK.
- Follow-ups: P-074.
