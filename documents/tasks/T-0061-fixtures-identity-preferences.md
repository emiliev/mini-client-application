# T-0061: `mc_fixtures_identity` preferences routes (U43, for the ST exemplar)

| Field | Value |
|---|---|
| Status | Done (merged 2026-11-27 `a16a332`; Verifier PASS `26d3164`) |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (fixtures; ADR-0011) |
| Branch | `fleet/T-0061-fixtures-identity-preferences` |
| Created | 2026-11-27 |
| Depends on | T-0039 (`mc_fixtures_identity`, `userForAuthorization`), the fixture conventions in T-0043, T-0047 and T-0051 |
| Related | plan 01 U43 ("preferences sync"), P1-22 (ST exemplar `settings_appearance`, AC6: "when dark mode is chosen, the whole app re-themes and the choice survives a restart (fixture identity sync)"), F056; `mc_ds_theme` `McThemeModeController`; ADR-0005 |

## Goal
Provide the backend for the ST exemplar `settings_appearance`. A signed-in user's appearance preferences (theme mode, density, reduce motion) are stored per user on the mocked server, so the setting follows the user. A test can check that it survives a restart and a sign-out followed by a sign-in.

## Scope
- **In: extend `utility/mc_fixtures_identity`. Don't create a new package.**
  - `GET /v1/me/preferences` returns `{themeMode, density, reduceMotion, updatedAt, version}`.
    - Defaults for a user who has never saved: `themeMode: system`, `density: comfortable`, `reduceMotion: false`, `version: 0`.
  - `PATCH /v1/me/preferences` takes a partial body of the same keys plus `ifVersion`.
    - It applies only the keys that are present and returns the full updated object.
    - `version` goes up by 1 on every successful write. `updatedAt` follows the fixed clock plus 1 s per write, as in T-0047.
    - **Optimistic concurrency:** if `ifVersion` doesn't match, respond 409 `version_conflict` with the current object in the body, so the client can re-apply its change or show it.
  - Validation returns 400 with a typed code:
    - `invalid_theme_mode` unless the value is `system`, `light` or `dark`;
    - `invalid_density` unless it is `comfortable` or `compact`;
    - `invalid_reduce_motion` for a non-bool;
    - `unknown_key` for any other key;
    - `invalid_body` for a non-object, or when `ifVersion` is missing or not an int;
    - `empty_patch` when no preference key is given.
  - Auth: 401 without a valid bearer.
  - Preferences are kept per user until `reset()`. One user's preferences are never visible to another.
  - Seed `u-101` with `themeMode: dark` so tests have a user whose preference differs from the default.
  - Sets and scenarios:
    - the existing identity sets gain these routes;
    - a new `identity.preferences_error` scenario makes only the preferences routes return 500 with the shared `injected_failure` body (T-0043 convention);
    - `identity.preferences_conflict` makes the next PATCH return 409 once.
  - Update `CONTRACT.md` and the snapshots.
- **Out:**
  - the settings feature itself (ST exemplar);
  - wiring `McThemeModeController` to these preferences (the ST exemplar does it);
  - notification or privacy preferences.

## Acceptance criteria
- **T-0061-AC1:** Determinism. The same requests for seed 42 return byte-identical bodies. The defaults and the `u-101` seed are pinned.
- **T-0061-AC2:** PATCH semantics.
  - A partial update changes only the keys in the body.
  - `version` and `updatedAt` advance on each write.
  - A stale `ifVersion` returns 409 with the current object and changes nothing.
  - Writes persist until `reset()`.
  - Users are isolated: two real users signed in through `/v1/auth/sign-in`.
  - Sign-out followed by sign-in as the same user returns the saved preferences.
- **T-0061-AC3:** Validation and auth. Every typed code is pinned, and so is the order of the checks (auth, then body, then version). 401 is returned without a bearer and with an expired one. Rejected writes change nothing and leave `version` unchanged.
- **T-0061-AC4:** Scenarios and contract.
  - `preferences_error` fails only the two preferences routes. `/v1/me` and favourites still work.
  - `preferences_conflict` fires exactly once.
  - The snapshots and `CONTRACT.md` are in step.
  - Every existing identity test is unchanged and green.
- **T-0061-AC5:** Gates.
  - The package is still pure Dart, coverage is ≥ 90 % and the fixtures check passes.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check` and format pass. Run format on the gated directories only (P-111).
  - The 50-run flake check passes on the changed targets.

## Log
- 2026-11-27: Created and dispatched (TL).
- 2026-11-27: Engineer implemented the routes, the two scenarios, CONTRACT.md, 5 snapshots and `preferences_test.dart`. Mutations 70/70 killed, flake check 50 runs clean, gates PASS.

## Outcome
Status: ready for review. `GET`/`PATCH /v1/me/preferences` are served by the existing identity domain (`lib/src/handlers/preferences_handlers.dart`); `u-101` is seeded `dark`.

| AC | Evidence |
|---|---|
| T-0061-AC1 | `preferences_test.dart` group "T-0061-AC1": pinned defaults as raw bytes, u-101 seed, seed in both sets, byte-identical sequences for seeds 42 and 7 |
| T-0061-AC2 | group "T-0061-AC2": partial apply, version and updatedAt, 409 with current, reset, two real users, sign-out/sign-in, held two-client probe (`_HoldingAdapter`), concurrent PATCHes, retry on current, 300-step random run against an independent model |
| T-0061-AC3 | group "T-0061-AC3": every code and parameter, 17 ordered pairs, 401 variants on both routes, nothing changes on rejection |
| T-0061-AC4 | group "T-0061-AC4": preferences_error (only the two routes), preferences_conflict (once, not consumed by rejected requests, per backend), sets, CONTRACT.md and routes.json; 5 new snapshots in `provider_contract_test`; the existing identity tests are unedited |
| T-0061-AC5 | [gates.md](../evidence/T-0061/engineer/gates.md) (closure, fixtures check with negative controls, `test //...` 191 pass, lint, arch, fork, format, l10n, coverage 99.0 %); [flake50.log](../evidence/T-0061/engineer/flake50.log); [mutations.log](../evidence/T-0061/engineer/mutations.log) (70 killed, 0 survived, 0 broken) |

Decisions: `updatedAt` = clock + version seconds per user (not a global tick); seeds in all sets; the conflict scenario is a handler override that writes nothing and fires once per backend (flag in the store); check order is in CONTRACT.md. Finding: [F-0061](../findings/F-0061-identity-preferences.md).
- 2026-11-27: Tech Lead approved the per-user `updatedAt` (clock + version seconds), which differs from T-0047's backend-wide tick. Recorded in F-0061 and `CONTRACT.md`.

## Review round
- **Important (re-arming):** `useScenario` never clears the store, so re-selecting `identity.preferences_conflict` did not arm it again without `reset()`. Fix: a new engine hook `MockScenario.onSelect(store)`, called by `MockBackend.useScenario` on every selection of a scenario (not on `null`). The conflict scenario uses it to clear its fired marker. Test `T-0061-AC4 selecting the conflict scenario again arms it again, with or without reset` (select, fire, `null`, select, fires again; two selections in a row give one arming; select with a read in between). Engine test `T-0061-AC4: onSelect runs on each selection, not on null` in `mc_mocked_backend`. `CONTRACT.md` updated. Mutants R1 to R6 kill it (76 of 76 killed in the re-run; 50-run flake check and gates re-run clean).
- **Nit (message):** the injected 409 now reads `Injected version conflict (scenario identity.preferences_conflict)`; a real mismatch keeps `The preferences are at version N, not M`. Both pinned in `T-0061-AC4 the injected 409 and a real mismatch have different messages`.
- **`updatedAt`:** accepted by the TL (see the Log line above).
- Scope note: this touches `utility/mc_mocked_backend` (7 lines in `backend.dart` plus one new test group). No existing test was edited.
- `origin/main` had no commits after the branch point (`c2c840b` already includes T-0060), so the merge was a no-op.

## Merge (TL)
- 2026-11-27: Review-first (ADR-0011). `/code-review` found 1 important bug (re-selecting the conflict scenario without `reset()` didn't re-arm it) and 2 nits.
  - The TL approved per-user `updatedAt`.
  - Review round `7a36048`: 76/76 mutations, plus a 7-line `MockScenario.onSelect` hook in `mc_mocked_backend`.
  - A single Sonnet Verifier pass gave PASS `26d3164` (about 84k tokens): its own two-user probe, 14 check-order pairs, 18/18 mutations, no defects.
  - The TL merged `--no-ff`. On the merge result, `check` passed, 191/191 tests passed, lint was clean and `mc_arch_check` reported OK.
