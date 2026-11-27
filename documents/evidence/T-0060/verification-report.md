# T-0060 verification report (Verifier, Sonnet tier)

**Verdict: PASS.** Commit under test: `9aba674` (detached worktree, own Bazel output base `/tmp/mc-ob-T-0060-verifier`). No defects found.

## AC results

| AC | Result | How it was re-derived |
|---|---|---|
| AC1 determinism | PASS | `verifier/verifier_oracle.dart.txt` section 5. Seed 42 is byte-identical across two backends and a repeat call, for all 4 categories x 3 difficulties. Seeds 42 and 43 differ for all 12. 1,000 rounds (10,000 questions, rotating category and difficulty): 10 distinct questions per round; 4 distinct ids and 4 distinct texts per question; exactly one correct. Correct-choice position share is 25.23 / 25.35 / 24.37 / 25.05 %, inside 20-30 %. |
| AC2 scoring | PASS | Oracle written from `CONTRACT.md` only, without reading `test/oracle.dart` or `scoring.dart`. 30 seeded rounds (all categories and difficulties; random wrong, null and correct choices; elapsed values at 0, limit-1, limit, limit+1 and random) were sent with the `answers` array shuffled: score, correct, per-answer breakdown points and breakdown order all match. Hand-computed examples E2 (137), E7 (126), E8 (133), E12 (1375), E14 (495) and E16 (475) match. limit-1 (100 points), limit (0), limit+1 (0), 0 ms (150) and limit/2 (125) are right for easy, medium and hard. Streak follows question order: the same answers in original, reversed and shuffled array order all scored 1,725. |
| AC3 validation and auth | PASS | Section 6. `unknown_category` (also for a missing one), `invalid_difficulty`, `invalid_seed` (8 malformed forms plus missing; 0 and 2147483647 accepted), `unknown_round` (also for a leading-zero seed), `answer_count_mismatch`, `unknown_question`, `duplicate_answer`, `unknown_choice`, `invalid_elapsed` (negative, negative with null choice, float, string) and `invalid_body` (missing `choiceId` key, no `answers`, string body) all returned. 401 for no bearer, expired bearer and a refresh token used as bearer, on both POST results and GET best. Two real users signed in through `/v1/auth/sign-in`: u-101's results never appear for u-100 and the reverse. `isNewBest`: first result true, tie false, lower false, strictly higher true, zero first result false (but it appears in best). `reset()` cleared u-101's best and restored u-100's seeded bests (870 / 1340). |
| AC4 contract and facts | PASS | 91 generated questions across comic_price, comic_pages, comic_year, creator writer, penciller and inker, character_team and character_debut_year were checked by my own regex against `GET /v1/comics/{id}` and `GET /v1/characters/{id}` (found via the list endpoints: 2,400 comics, 1,500 characters): 0 mismatches. Snapshots, CONTRACT parity and image resolution rely on `provider_contract_test` (passes in every run here; mutants of the snapshot and image fields were killed). I did not write a separate image resolver. |
| AC5 packaging | PASS | `tool/checks/T-0060-AC5_gates.sh` with the lockfile-mode gate: all 12 gates PASS (`verifier/gates.md`). Coverage by my own lcov parser over the 5 `coverage.dat` files: 456/458 = 99.6 % (uncovered: `bank.dart` lines 133 and 281). `--runs_per_test=50` on all 5 targets: 0 failures (`Stats over 50 runs` seen). Outside the package only `appMockDomains` (`app_media.dart`) with its `app_core` pubspec, BUILD and one `T-0060-AC5` test, the root `pubspec.yaml` workspace line, and `tool/checks/T-0060-AC5_gates.sh` changed. |

## Mutations (`verifier/mutations_verifier.log`, `verifier/mutations_verifier.sh.txt`)
- Own mutations: 12, all killed. V1 time bonus rounded through a double; V2 streak starts at 1; V3 timeout boundary exclusive; V4 `isNewBest` uses `>=`; V5 choice shuffle skips its first swap; V6 best read ignores the user; V7 result write ignores the user; V8 streak follows the answers array order; V9 best overwritten by a lower score; V10 zero first result becomes a new best; V11 choice shuffle independent of the seed; V12 expired token accepted. V11 and V12 did not build the first time (mutant problems, not product problems); they were rewritten and killed.
- Engineer mutants re-run: 8 (S1, S9, S13, S16, S19, R14, H44, B35), all killed.
- 0 survivors.

## Merge check
`git merge --no-commit --no-ff origin/main` merged cleanly (the workspace list took `mc_ds_overlays` next to `mc_fixtures_editorial`; the `app_core` BUILD and pubspec auto-merged). After `fvm dart pub get --offline`, `test --lockfile_mode=error //...` gave **190 tests pass** (187 plus 3 from main). Then `git merge --abort`: tree back at `9aba674`.

## Integrity
- Every AC has `T-0060-ACn` tests (12, 14, 36, 27 and 1 mentions for AC1 to AC5).
- No `ignore:`, `ignore_for_file`, `skip:` or `@Skip` in `lib`, `test` or `tool`. All package files are new, so nothing was deleted or weakened.

## Notes (non-blocking)
- In the gates run, `test //...` reported "Executed 0 out of 187" because results were cached in the same output base; the uncached editorial run (5 of 5) and the merge-check run (26 of 190 executed) both passed.
- `CONTRACT.md` was enough to write the oracle from; I found no ambiguity in the scoring rules.

Evidence in `documents/evidence/T-0060/verifier/`: `verifier_oracle.dart.txt` (run with `fvm dart run` inside the package; final output `TOTAL FAILS: 0`), `gates.md`, `mutations_verifier.log`, `mutations_verifier.sh.txt`.
