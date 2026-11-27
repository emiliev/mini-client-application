# T-0061 Verification report (fresh Verifier, Sonnet tier)

Verified commit: `7a36048`. Verdict: **PASS**. No defects found.

| Item | Result | Evidence |
|---|---|---|
| AC1 defaults, `u-101` dark seed, seed 42 byte-identical | PASS | `verifier/probe_test.dart.txt` test "AC1" (two backends, raw bodies compared) |
| AC2 partial PATCH, version/updatedAt per user, stale 409 with current and no change, concurrent PATCH (200 + 409), sign-out/in keeps prefs, `reset()` clears, two real users isolated | PASS | probe "AC2" |
| AC3 every code and `parameter`; 14 check-order pairs of my own; 401 with no bearer, expired bearer, refresh token as bearer (GET and PATCH, even with a garbage body); rejected writes change nothing | PASS | probe "AC3" |
| AC4 `preferences_error` fails only the two routes (`/v1/me` and favourites 200, body `injected_failure`); `preferences_conflict` fires once, re-arms on a new selection with `reset()`, without `reset()`, after `null`, and on a repeated selection; injected message differs from the real one; snapshots, CONTRACT.md and routes.json in step (provider_contract_test green) | PASS | probe "AC4" |
| No existing test edited | PASS | the test diff `origin/main...7a36048` has 0 removed lines; only additions (preferences_test.dart, snapshot cases and 5 snapshots, one engine test group). No `ignore:`, `skip:` or `markTestSkipped` added |
| `onSelect` hook | PASS | `backend.dart`: 7 lines, documented on the field. Called on every non-null selection, never for `null` (my mutants V1, V2, V3 killed). Other domains unaffected: `test //...` 191 pass |
| AC5 gates | PASS | `verifier/gates.md` (closure, fixtures check with negative controls, lint, arch, fork, format, l10n) and `test --lockfile_mode=error //...`: 191 pass |
| Coverage, own parser (max hit per DA line over the four coverage.dat files) | 208/210 = 99.0 % | `verifier/coverage.txt` (uncovered: `domain.dart` lines 40 and 111, both pre-existing) |
| 50-run flake check, identity and mocked_backend targets | 0 failures | `verifier/flake50.log` |
| Mutations | 18 of 18 killed, 0 survived, 0 broken | `verifier/mutations.log`: 8 of the engineer's (V7, A4, O5, U4, S7, R2, R4, C19) and 10 of mine (onSelect only on change, onSelect for null, onSelect gets a copy of the store, reduceMotion applied only when true, density skipped when default, user key by id length, refresh token accepted as bearer, expired bearer accepted, sign-out wipes preferences, a stale write that applies then conflicts) |
| Merge check | PASS | `origin/main` (`c2c840b`) is already an ancestor, so the merge is a no-op ("Already up to date"); `test --lockfile_mode=error //...` 191 pass |
| Integrity | PASS | `T-0061-AC1..AC4` test names present in `preferences_test.dart` (5, 14, 10 and 11 occurrences) and in `mocked_backend_test.dart` (AC4); AC5 is the gates script |

## Notes
- The probe was run as a temporary test file, then removed from the tree. Only `.dart.txt` is kept.
- Mutation runner and coverage parser are in scratch only. The tree was clean after each mutation.
- Nothing was pushed. Bazel output base `/tmp/mc-ob-T-0061-verifier` was shut down.
