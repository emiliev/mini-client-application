# T-0052: `mc_feature_flags` (U09) with the flags slice of `mc_fixtures_platform` (U49)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier, **Sonnet tier** (service kit used, not copied, by bricks; ADR-0011) |
| Branch | `fleet/T-0052-feature-flags` |
| Created | 2026-11-27 |
| Depends on | T-0039 (`mc_session` epoch, `mc_fixtures_identity`), `mc_storage`, `mc_config`, `mc_monitoring`, `mc_api_client`, `mc_api_errors` |
| Related | plan 01 U09, U49, P1-05, §3.4 (root DI list), DB+ and ST+ sets; P1-21 `store_home`, P1-22 `settings_appearance`; F100 `system_status`, F062 `developer_feature_flags` (later); ADR-0005 |

## Goal
The DB and ST exemplars, and later bricks, need typed feature flags and experiments. They should evaluate the same way on every run, work offline from a last-known-good cache, and allow local overrides in dev. Boot must never wait on the network for them.

## Scope
- **In: `utility/mc_feature_flags` (UD).** Plan deps: `mc_prelude`, `mc_di`, `mc_config`, `mc_storage`, `mc_api_client`, `mc_api_errors`; add `mc_session` and `mc_monitoring` (document why in the BUILD and the README).
  - **Typed registry.** `FeatureFlag<T>` with `key`, `defaultValue` and `description`, for `bool`, `int`, `String` and enum (via a codec). Keys are unique, and registering a duplicate throws. Features declare their flags as `const` values in their own package; the kit holds no product flags.
  - **Evaluation order**, documented and pinned:
    1. local override (only when `AppConfig.env` is not release-like; overrides are persisted in `mc_storage`);
    2. remote value from the last successful fetch for the **current session epoch**;
    3. last-known-good remote value from storage, where there is one and no fetch has succeeded yet in this epoch;
    4. `defaultValue`.

    A remote value of the wrong type falls back to the next source and is reported once to `mc_monitoring`. Unknown remote keys are ignored.
  - **Experiments.** `Experiment` has `key` and `variants` with integer weights. Bucketing is deterministic: a documented stable hash (for example FNV-1a 32-bit over UTF-8 `"<experimentKey>:<subjectId>"`, **never `String.hashCode`**) mod 10000 against cumulative weights. The subject is the signed-in user id, or else a random install id persisted in storage. Remote config supplies weights; a local override can force a variant.
  - **Remote fetch.** `GET /v1/flags` (auth optional; a bearer adds user targeting) via the shared Dio.
    - Fetch on start and when the session epoch changes. A result that arrives for a stale epoch is dropped (the epoch rule: check after every await, before a write).
    - A failed fetch keeps the current values and never throws to callers.
  - **API.**
    - `T value<T>(FeatureFlag<T>)` is synchronous.
    - `Stream<T> watch<T>(FeatureFlag<T>)` emits the current value, then only distinct changes.
    - `String variant(Experiment)`.
    - `Future<void> refresh()`.
    - `FeatureFlagOverrides` with set, clear and clearAll (rejected in release-like envs).
  - **DI.** `FeatureFlagsDIInitializer` goes in `app_core`'s `rootInitializers` after `ApiAuthDIInitializer`, as plan §3.4 orders it. Update that comment. It must not block boot on the network: register at once with cached or default values, then fetch in the background.
- **In: `utility/mc_fixtures_platform` (UM, pure Dart), flags slice only.**
  - `GET /v1/flags` returns `{flags: {key: value}, experiments: [{key, variants: [{name, weight}]}]}`.
  - Targeting: one seeded user gets a different value for at least one flag than anonymous does.
  - Sets and scenarios `default`, `empty` and `server_error`, with one identical body each (T-0043 convention), plus `platform.flags_malformed` with a wrong-typed value. Add a `CONTRACT.md`.
  - Register the domain in the app's mock domains.
- **Out:** the developer flags screen (F062), remote config beyond flags, system status, analytics exposure events (T-0053 `mc_analytics` will add the hook), and Android.

## Acceptance criteria
- **T-0052-AC1: evaluation order.** Each of the four sources wins exactly when the order says it should, with a test per transition.
  - An override is ignored in a release-like env.
  - A wrong-typed remote value falls back and is reported once.
  - A last-known-good value is used after a restart with the backend failing.
  - Mutations remove or reorder each source and must be killed.
- **T-0052-AC2: experiments.**
  - Bucketing is stable across instances and restarts, and against a golden table of at least 20 `(experiment, subject) → variant` rows computed by an independent implementation in the test.
  - Over 10,000 synthetic subjects the split is within ±2 % of the weights.
  - Weight 0 never gets a subject.
  - A forced variant wins.
  - Changing the user changes the subject.
- **T-0052-AC3: session and fetch.**
  - A user switch refetches, and the targeted flag changes value.
  - A fetch that resolves after the switch for the old epoch is dropped. Use a held response and test both orders.
  - A failed fetch keeps the values and doesn't throw.
  - `watch` emits distinct changes only.
  - Boot is not blocked: hold the flags response and assert the app reaches home. Use an app-level test, or e2e on your own simulator.
- **T-0052-AC4: fixtures.** Determinism for seed 42. The sets and scenarios match their bodies. The targeting and the malformed scenario work. The contract snapshots match. The package is pure Dart (closure check with a negative control), registered, and passes the fixtures check.
- **T-0052-AC5: gates.**
  - Coverage ≥ 90 % for both packages.
  - `test --lockfile_mode=error //...`, lint, `mc_arch_check`, `rules_fork.sh check`, format and `l10n_check` pass.
  - Globs use `MC_GENERATED_DART`.
  - The sim app builds, and the mini_client e2e still passes on your own simulator (deleted afterwards).
  - Evidence goes in `documents/evidence/T-0052/engineer/`, with a `tool/checks/T-0052-AC5_gates.sh` and a mutation script that refuses a dirty package and tells a broken build from a killed mutation.

## Log
- 2026-11-27: Created and dispatched (TL).
