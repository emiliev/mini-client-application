# T-0034: Remove the `characters_list` exemplar's workarounds (`mc_feature_flow`, `mc_paging`, base URL)

| Field | Value |
|---|---|
| Status | Ready (dispatch after T-0032 merges) |
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
5. **mocktail** is in the lock now. Moving F-0024's hand-written `MockMonitoring` to mocktail is optional and out of scope.

## Scope
- **In:** decisions 1–3, implemented in `mc_feature_flow`, `mc_paging` and `mc_config`/`mc_api_client`. Remove the marked workarounds in `feature/characters/characters_list` so it matches plan 01 §3.3's code.
- **Out:** `mcgen wire`, and any changes to the exemplar beyond removing the workarounds.

## Acceptance criteria
- **T-0034-AC1:** A widget test shows that `context.di<T>()` inside `BlocProvider.create` doesn't throw and doesn't register a dependency on the inherited scope. A rebuild of the scope doesn't recreate the bloc.
- **T-0034-AC2:** A `FeatureFlow` with `provide:` makes the provided instance resolvable inside the flow, and nowhere outside it. With `localizationsDelegates:`, the flow's strings resolve for `en` and `de`. Both are tested in `mc_feature_flow`.
- **T-0034-AC3:** A freezed bloc state holding `PagedState<T>` compiles with the default `copyWith`, including the deep `copyWith`, in a test package. The generated outputs are still byte-identical to build_runner's (`spike_reference.sh`).
- **T-0034-AC4:** `apiBaseUrl` without a trailing slash is normalised. A retrofit path with a leading slash is rejected or flagged by a test or lint. The exemplar uses `'v1/characters'`, and its requests still hit `/v1/characters`.
- **T-0034-AC5:** `characters_list` has no workaround markers left (grep for the T-0032 marker comments). All T-0032 ACs still pass unchanged, and the T-0032 byte-identity and cutoff checks still pass. Gates: `test //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format, coverage ≥ 90 % for every touched package.

## Log
- 2026-11-25: Created (TL) from T-0032's handoff questions.
