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
- 2026-11-27: Engineer (Sonnet). `utility/mc_feature_flags` and `utility/mc_fixtures_platform` built and registered in the root `pubspec.yaml` (`pubspec.lock` and `MODULE.bazel.lock` unchanged; `test --lockfile_mode=error //...` passes). Outside the two packages: `app_core` (root list, `appMockDomains`, its `pubspec.yaml` and `BUILD.bazel`, one new test `feature_flags_boot_test.dart`), edits to `boot_test.dart` (below), this task file, `tool/checks/T-0052-AC5_gates.sh`, `documents/evidence/T-0052/engineer/` and F-0052. `mc_test_utils` was **not** touched: see Follow-ups.
- 2026-11-27: Decisions inside the scope (details in F-0052 and the package README):
  - Flags are `const FeatureFlag<T>(key, defaultValue, description, codec)` with the codecs `BoolFlagCodec`, `IntFlagCodec`, `StringFlagCodec` and `EnumFlagCodec(values)`. A flag registers itself on first use; `registry.registerFlag` of a taken key throws `DuplicateFlagKeyError`, and so does using a *different* flag with a taken key.
  - The order is read literally: a successful fetch ends the last-known-good, so a key the server omits or sends with the wrong type is the default. The last-known-good is one cache slot and is used only for the user it was fetched for.
  - Overrides are accepted only for `dev`, `e2e`, `perf` and `test`; every other env name (and a typo) is release-like. A rejected call returns a `FlagOverrideFailure`; nothing throws.
  - Remote experiment weights replace the declared ones by variant name (an omitted variant has weight 0, an undeclared one is ignored). A malformed entry or one with no positive declared weight is ignored and reported once.
  - Bucket = FNV-1a 32 over UTF-8 `"<experimentKey>:<subject>"` modulo 10000; a variant wins when `bucket < cumulative * 10000 ~/ total`. Subject = the signed-in user, else a random install id (lazy, persisted).
  - The epoch is observed on every read as well as on `authState`, because a sign-in as the same user starts a new epoch without an event. `refresh()` joins a fetch in flight for the same epoch.
  - Auth is optional on `GET /v1/flags`: any bad bearer is anonymous (never 401). The fixtures' targeting: `u-100` gets `search.layout=list` and `store.promo_banner=true`; `u-101` gets `catalogue.page_size=40`.
- 2026-11-27: Existing tests touched, declared (nothing deleted, skipped or weakened, no `// ignore:`):
  - `app_core/test/boot_test.dart`, "the root list registers every root type once": `recentTraffic hasLength(1)` became "the traffic for `/v1/nothing` has length 1", because the root list now also fetches `/v1/flags` at boot (a 404 there).
  - `app_core/test/boot_test.dart`, the two `testWidgets` that boot the real root list and end right after `pump()` ("a failing root initializer ... Retry succeeds" and "Retry escapes a never-completing root initializer"): each ends with `await tester.pump(const Duration(milliseconds: 10))`, because Dio starts the flags request on a zero timer that `pump()` does not fire ("A Timer is still pending"). F-0052 traps 1 to 3.

## Outcome
`utility/mc_feature_flags` (UD, pure Dart) gives bricks typed flags (`bool`, `int`, `String`, enum), a four-source evaluation order, deterministic experiments, local overrides for dev and a remote fetch that follows the session epoch. `FeatureFlagsDIInitializer` is in `app_core`'s root list right after `ApiAuthDIInitializer`; it registers at once with saved or default values and starts the fetch without waiting for it. `utility/mc_fixtures_platform` (UM, pure Dart, flags slice) serves `GET /v1/flags` with two targeted users, an anonymous fallback for any bad bearer, four sets (`platform.default`, `.empty`, `.flags_malformed`, `.server_error`) and the matching scenarios; `PlatformMockDomain` is in `appMockDomains`. Both packages are registered in the workspace.

| AC | Evidence |
|---|---|
| AC1 | `evaluation_test.dart` (18 `T-0052-AC1` tests): default wins; remote beats default; omitted and unknown keys; last-known-good (LKG) after a restart with the backend failing, and while the first fetch is held (then the remote of this epoch beats it); a successful fetch ends the LKG; override beats remote, LKG and default, and clear and clearAll fall through in order; overrides survive a restart; **5 release-like envs** (`release`, `prod`, `staging`, `production`, empty) reject all five override calls and do not read a saved override (the dev run shows it is still saved), and 4 dev-like envs accept; a wrong-typed remote value falls back and is reported **once** per key however often it is read or refetched; which values count as the wrong type (fraction for int, string for bool, number for string, a name no enum has; a JSON null is "no value" and is not reported); a wrong-typed saved override; LKG scoped to a user (control: the owner uses it); corrupt and wrong-shaped caches; the fixtures (default and `flags_malformed`). `registry_overrides_test.dart` (15 `T-0052-AC1` tests): duplicate keys throw (flags, experiments, the lazy path, a different flag or type with a taken key), a blank key and malformed experiments, equality, codecs, override persistence, a save failure returned as a value, `isReleaseLikeEnv`. Mutations O1 to O4, R1 to R5, W1 to W7, V1 to V7, G1 to G7 |
| AC2 | `experiments_test.dart` (22 `T-0052-AC2` tests): the **28-row golden table** (4 experiments, up to 10 subjects each, including `''`, `user-é` and a 32-character id) agrees with literals computed in Python, with an in-test BigInt FNV oracle and with the kit, bucket and variant, and again through `variant()` for signed-in users; the published FNV vectors (`""`, `a`, `foobar`); `String.hashCode` is not it. The same variant on a new instance and after a restart; the install id is made once and saved. Changing the user changes the subject. **10,000 subjects, three id schemes, four experiments, each within 2 points of its weights**, and a negative control (wrong expected weights) fails. A weight of 0 never wins (all 10,000 buckets, each position, and through remote weights); no positive weight gives the control; boundaries. Remote weights; omitted and undeclared variants; malformed weights (10 shapes) fall back and are reported once without failing the fetch; LKG weights after a restart; a forced variant wins over the bucket and over remote weights and survives a user change; an undeclared forced variant is rejected. Mutations X1 to X7, B1 to B9, S1 to S4 |
| AC3 | `session_fetch_test.dart` (25 tests), `di_test.dart` (4), `registry_overrides_test.dart` (3), app_core `feature_flags_boot_test.dart` (4). Start fetches once, anonymously; a user switch refetches with that user's bearer and the targeted flag changes (`search.layout` grid to list, through the stream alone, with no read in between); a same-user sign-in keeps the values meanwhile; another user's values are not kept. **Epoch rule with held responses (the backend answers at once, the test releases the answer):** old released after the switch but before the new one, and new first then old, for a user switch, and both orders for a sign-out; the stale response applies nothing and writes no cache; a negative control applies a held response of the current epoch; a response after `dispose` is dropped. A failed fetch keeps the values and never throws: 500, offline, timeout, malformed JSON, five wrong-shaped bodies, a first fetch that fails, a store that fails to write and one that throws. `watch` emits the current value, then only distinct changes (same remote value, same override, an unrelated flag, a user switch, cancel). Concurrent `refresh` calls share one request. **Boot:** `di_test` holds the response and the initializer still completes; `feature_flags_boot_test` boots the real root list with the response held on a completer: home is on screen, the value is the default, the request was made, then the value arrives; a second test boots with `platform.server_error` and reaches home; the flags sit right after `ApiAuthDIInitializer`. Mutations E1 to E16 |
| AC4 | `mc_fixtures_platform`: `flags_test.dart` (7: seed 42 byte-identical across calls, backends and `reset()`; seed 7 gives the same bytes (documented); shape; targeting for `u-100` and `u-101`; five bad bearers are anonymous 200s; the malformed body; the route), `fixture_sets_test.dart` (8: the four sets and their scenarios; set and scenario answer the same status, body and content type for anonymous, `u-100` and `u-101`; a negative control; switching scenarios on and off), `provider_contract_test.dart` (6: **10 snapshots** match, none unused, a drift negative control, manifest, domain, scenarios and sets agree, `CONTRACT.md` names every key, set, scenario and code). Pure Dart: `no_flutter_test` (with a detector control) and the closure check in the gates (1,339 targets, no Flutter marker; positive control `mc_fixtures_media`; negative control: a throwaway target depending on it and on media shows them). Registered in the root `pubspec.yaml` and in `appMockDomains` (`feature_flags_boot_test`). Fixtures check: none of 33 production targets reaches it (positive control: a test of mc_feature_flags; negative control: a throwaway production target). Mutations P1 to P12 |
| AC5 | [`T-0052-AC5_gates.sh`](../../tool/checks/T-0052-AC5_gates.sh) -> [PASS](../evidence/T-0052/engineer/AC5_gates.md): the closure checks, registration, the fixtures check, `test //...` **161/161**, `build --config=lint //...`, `mc_arch_check`, `rules_fork.sh check`, `dart format` (0 changed), `l10n_check`, `build --config=sim` of the app and the sandbox. **Coverage** (lib/, generated excluded): mc_feature_flags 360/364 = 98.9 %, mc_fixtures_platform 51/55 = 92.7 %. `test --lockfile_mode=error //...` passes; both lock files unchanged. Globs use `MC_GENERATED_DART`. **e2e:** the 9 existing `mini_client` journeys pass on `mc-T-0052-engineer-<pid>` (`tool/e2e_ios.sh`, [summary](../evidence/T-0052/engineer/mini_client/e2e-summary.md), 34 screenshots at most 1200 px); the simulator was deleted (`simctl list` shows none) |

**Mutations:** [mutations.sh](../evidence/T-0052/engineer/mutations.sh) (`MC_TASK=T-0052 MC_ROLE=engineer`): **78 of 78 killed by a failing test**, 0 survived, 0 broken ([log](../evidence/T-0052/engineer/mutations.log)). The script refuses a dirty tree, sets its restore trap before the first edit, formats each mutant (the build checks formatting), calls `Build did NOT complete` and a timeout broken, and counts only `FAILED in` as a kill. Runs that found weak tests, now pinned: a `null` remote value that must not count as a wrong type (R5), remote weights with no positive declared weight that must fall back even where the control would be the answer (X3), a fractional weight (S2), a non-map variant that must not fail the whole fetch (S4), a negative weight (S3), a start that waits for the fetch (E14, which first hung instead of failing: the DI tests now time out into a failure). A redundant `variants.isEmpty` check was removed from the source (its mutant was equivalent).

Test integrity: no tests deleted, skipped or weakened; no `// ignore:`; no golden touched. The edits to existing tests in `boot_test.dart` are listed in the Log. Findings: [F-0052](../findings/F-0052-feature-flags.md). ADRs: none.

Follow-ups (for the TL's `pending-work.md`):
- `McTestContainer` (`mc_test_utils`) repeats the root list and does not include `FeatureFlagsDIInitializer`, so a BDD test cannot `RootImport` the flags yet. Adding it starts a `/v1/flags` fetch in every feature test (a 404 on harnesses without the platform domain); decide when.
- A sign-in as the same user starts a new epoch without a `SessionChanged` or `authState` event. The flags handle it on the next read; an epoch stream in `mc_session` would let `watch` react at once.
- The LKG cache is one slot (see F-0052); a slot per user is possible if the app ever needs it.

Questions for the PO: none.

## Review round (2026-11-27, Engineer)
`origin/main` (T-0049, T-0051) merged first: one conflict, the test list in `app_core/BUILD.bazel` (kept `feature_flags_boot_test` and `route_nesting_test`). `pubspec.lock` and `MODULE.bazel.lock` are unchanged (`test --lockfile_mode=error //...` passes), and the two `boot_test` edits still hold on the merged tree.
1. **Weight overflow (important).** `maxVariantWeight = 1,000,000,000` (exported, documented in the README and F-0052): a remote weight above it is malformed (reported "malformed", the declared weights apply); a declared weight above it is an `ArgumentError`. With the cap and fewer than 900 variants the scaled sum stays below 2^53, so VM and JS agree. Tests: a 1e15 remote weight falls back where the old code returned the control; the cap itself is accepted and cap + 1 is not; `pickVariant` at three cap weights is exact on every bucket edge. Mutations C1 to C4.
2. **`watch()`-only consumers and a same-user re-sign-in.** `mc_event_bus` and `authState` announce a change of user only, so a hook was needed. **Change outside the package, justified:** `mc_session` gained `SessionEpochs.epochChanges` (`Stream<int>`, one event per new epoch), implemented by `Session`; test `T-0052-AC3 epochChanges ...` in `session_test.dart`. It is a separate interface, so the three `SessionReader` test doubles are unaffected. `FeatureFlags` listens when the session is a `SessionEpochs`. Tests: a `watch` subscriber gets the new epoch's value with no `value()` read; a `SessionReader`-only session still refetches from `authState` alone; a read right after `signIn` (before any event) does not return the other user's values. Mutations H1, H3, H4, and E5/E6 are now killed by those tests.
3. **`dispose()`.** Closes every `watch` stream (listeners get `done`); a `watch` after dispose emits its value and ends; `refresh()`, `start()` and reads send no request after it (the request recorder counts them). Mutations D1 to D3.
4. **`set` and `forceVariant` never throw.** A taken or blank key is a `FlagOverrideFailure` with the new reason `invalidFlag`; nothing is saved or applied. Mutations N1, N2.
5. **Install id.** The save result is checked: a failure warns once (`could not save the install id`) and a later read tries again, until it is saved (a store that fails twice: three attempts, one warning, then no more writes). Mutations I1, I2, X7.
6. **Report keys** carry the kind (`remote:flag:<key>`, `remote:experiment:<key>`, and the same for overrides): a flag and an experiment that share a key are both reported. Mutation K1.
7. **Empty `variants: []`** is malformed (null), reported "malformed"; the message now differs from the "no positive declared weight" one, so the test can tell the two apart (the two were equivalent before). Mutation K2.
8. **Duplicate remote variant names** are malformed, reported, and the declared weights apply. Mutation K3.
9. **Privacy.** When the user changes (a sign-out, or another user) `feature_flags.cache` is deleted at once; a same-user sign-in keeps it. Tests run on a backend that fails after the sign-out and after the user switch (the file is gone), and a restart as anonymous with the backend failing sees the defaults. In F-0052 (decision 12) and the README. One existing AC1 test changed: the "owner uses the cache" control now writes the cache after signing in, because the sign-in rightly clears one written for nobody. Mutations Y1 to Y3.

**Re-run, from the final tree** (the only commit after the gates and mutation runs is this section and the logs):
- `T-0052-AC5_gates.sh` PASS ([AC5_gates.md](../evidence/T-0052/engineer/AC5_gates.md)): `test //...` **163/163**, lint, `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check`, the sim builds, closure and fixtures checks; coverage mc_feature_flags 416/423 = 98.3 %, mc_fixtures_platform 51/55 = 92.7 %.
- Mutations: **98 of 98 killed**, 0 survived, 0 broken ([log](../evidence/T-0052/engineer/mutations.log)): the earlier 78 plus 20 for items 1 to 9. The first run had 4 survivors and 3 broken (E5/E6 survived because the new epoch stream made the old paths redundant, so tests now pin each path alone; Y3 needed the backend to fail before the same-user sign-in; C1 and D1 left an unused name; D3 hung instead of failing). One planned mutant, "the epoch listener does not observe", was dropped: it is equivalent, because the `watch` listener calls `value()` on the notification, and `value()` observes.
- e2e: 10 `mini_client` targets PASS on `mc-T-0052-engineer-<pid>` (deleted; `simctl list` shows none).
