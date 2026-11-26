# Verification report — T-0042: `tool/ide_sync`

- **Verifier:** crew: Verifier (fresh agent, Sonnet tier, ADR-0011; not the implementer)
- **Date:** 2026-11-26
- **Branch / commit verified:** `fleet/T-0042-ide-sync` @ `b13f51f`
- **Simulators:** `mc-T-0042-verifier-75460` (AC2) and `mc-T-0042-verifier-16028` (e2e), iPhone 17 Pro, iOS 26.2, both deleted (`simctl list` shows none)
- **Bazel:** own output bases `/tmp/mc-ob-T-0042-verifier` and `-fresh`, both shut down
- **Verdict:** **FAIL** (one Minor defect in the AC4 check, see Issues. Everything else PASS. Narrow re-verification: AC4 plus the gates.)

## Gates re-run independently (tool/checks/T-0042-AC5_gates.sh on the synced tree)
| Gate | Result |
|---|---|
| `test //...` | PASS, 101 of 101 |
| `build --config=lint //...` | PASS |
| `mc_arch_check`, `rules_fork.sh check`, `dart format`, `l10n_check` | PASS |
| T-0032-AC6 byte-identity with build_runner (synced tree) | PASS |
| ide_sync fixture suite (`T-0042-AC5_script_tests.sh`) | PASS, 72 rows, 0 FAIL |
| `tool/checks/T-0033-e2e_prepare.sh` (fresh output base, 18 files, 2 negative controls) | PASS |
| L4 e2e: `tool/e2e_ios.sh` on the `prepare_pub_project.sh` copy, `characters_journey_test` | PASS (45 s), `verifier/e2e/` |

## Acceptance criteria
| AC | Scenario | Check | Really asserts? | Result |
|---|---|---|---|---|
| AC1 | fresh clone, before 176 errors and 11 warnings, after 0 and 0; deleting `character.freezed.dart` gives 14 errors | `T-0042-AC1_analyzer.sh` (fresh output base) | yes, has a negative control | PASS |
| AC2 | `fvm flutter run -d <own sim>` from `app/mini_client`; hot reload OK; screenshot (552x1200) viewed: "Mini Client", "Marvel universe", "Config: env=dev", Characters button, debug banner. Without `app_config.json` the run fails | `T-0042-AC2_flutter_run.sh`, `AC2_home.png` | yes | PASS |
| AC3 | no-op sync copies 0 of 23, mtimes equal; one-model edit copies 1 file; add then remove a model deletes its file and manifest line; `--watch` 2.3 s; a `bazel test` ran first (step 0) and the sync still found all outputs; fixtures 20 cover the pubspec and config edits in watch mode | `T-0042-AC3_incremental.sh`, script tests 17 to 20 | yes, 2 negative controls | PASS |
| AC4 | `git status` unchanged after a sync; none of 23 synced files tracked; `git add -f` is reported; no glob picks up a synced or gen-l10n file; planted file reported; synced `build` and `test //...` run 0 actions and 0 of 101 tests; `--clean` removes the synced files and the Xcode scaffolding (checked by hand, the tracked tree stays clean; fixture 19) | `T-0042-AC4_safety.sh` | yes, but see Issue 1 | **FAIL on a cold output base**, PASS on a warm one |
| AC5 | gates and 72 fixture rows green | `T-0042-AC5_gates.sh`, `T-0042-AC5_script_tests.sh` | yes | PASS |

## Mutations (6 on `ide_sync`, 1 on `prepare_pub_project.sh`; each reverted afterwards, tree clean)
| Fix | Mutation | Red test |
|---|---|---|
| `place()` returns failure | `cp ... \|\| true` | 15 (copy mode) |
| failed-write exit | drop `\|\| { log "failed to write"; return 1; }` | 15 (copy, `--link`, names the file) |
| clear `missing`/`skipped` per sync | delete the `rm -f` | 17 |
| Xcode guard before any write | drop the `bad` check | 18 (non-zero exit, nothing written) |
| watch fingerprint | drop `pubspec.yaml` and `l10n.yaml` | 20 (pubspec edit) |
| watch baseline before first sync | swap the two lines | 20 (edit during the first sync) |
| duplicate `assets:` key in `prepare_pub_project.sh` | remove the early exit | `T-0033-e2e_prepare.sh` FAIL: "Duplicate mapping key" |

Not mutated: the exact-path BEP listing. It is covered by fixture 16 and by AC3 step 0 (a real `bazel test` first), which passed.

## Test-integrity audit
- Tests deleted, skipped or weakened: none. The diff against `origin/main` touches no test file.
- Lint suppressions added: none.
- Golden files updated: none.
- BUILD diff: the 7 `glob()` calls gained or changed `exclude` only (`MC_GENERATED_DART`); `bazel test //...` is green. Note: the exclusion for `.config.dart` narrowed from `**/*.config.dart` to `lib/src/di/*.config.dart` (review item 10, on purpose, so a hand-written `app.config.dart` stays a source). The `.g.dart` pattern widened from `lib/**` to `**`.

## Visual acceptance
| Checkpoint | Screenshot | What is visible | Matches AC? |
|---|---|---|---|
| Home after `flutter run` | `documents/evidence/T-0042/verifier/AC2_home.png` | title, "Marvel universe", font sample, "Config: env=dev", two buttons | yes |

## Issues found
1. **(Minor, check defect) `tool/checks/T-0042-AC4_safety.sh:114-115` fails on a cold output base.** Step 3 compares the hashes of `bazel-bin` after run A (`build` and `test //...`) with run B (after the sync). On a fresh base, B has one extra file: `bazel-bin/external/ai_rules_dart+/dart/private/analyzer_sdk_summary.sum`. Cause (confirmed): `build //...` and `test //...` do not build that tool artifact, but the sync's own `bazel build` of the codegen targets does. Every file in A has identical bytes in B, and B runs 0 actions, so the claim holds for every shared output. The engineer's run passed because their output base was warm. On my warm base the check passes (21246 files, same bytes). Evidence: `AC4_safety_cold_base_FAIL.md` and `AC4_safety_warm_base_PASS.md`. Fix: run `ide_sync` (or build the codegen targets) before A, or compare "A is a subset of B with equal hashes" and name the extra files in the report. Re-run on a fresh output base.

## Notes for the Tech Lead
- Everything else is clean. The fix is in the check only, not in `ide_sync`.
- `--clean` leaves empty `ios/Runner.xcodeproj` and `ios/Runner.xcworkspace` directories, and Flutter's own ignored files (`ios/Flutter/`, `GeneratedPluginRegistrant.*`, gen-l10n). None is tracked and `git status` stays clean.
- T-0041 needs `MC_GENERATED_DART` in its BUILD before merge (engineer's follow-up 2).

## Re-verification at 351e732 (narrow)
- **Verdict: PASS.** Evidence: `documents/evidence/T-0042/verifier/re/`. No simulator was created. Bazel output base `/tmp/mc-ob-T-0042-verifier-fresh2` (fresh), shut down afterwards.
1. **Issue 1 fixed.** `T-0042-AC4_safety.sh` on a fresh output base: PASS. It compares the unsynced run as a hash-equal subset of the synced run (21244 files, same bytes), requires 0 actions and 0 of 101 tests in the synced run, and lists the one extra file: `bazel-bin/external/ai_rules_dart+/dart/private/analyzer_sdk_summary.sum` (`AC4_fresh2.md`).
2. **Negatives.**
   - `MC_AC4_TAMPER=1`: FAIL as it must. The hook appended to `bazel-bin/app/mini_client/_stage.dart_analyzer_summary.sum`, a regular Bazel-made file. `git status` was clean afterwards (`AC4_hook_tamper.md`).
   - My own tamper: I changed the victim filter to `package_config.json` and truncated it to one byte, in a throwaway WIP commit that is not part of this branch. The check FAILED on that file (`AC4_manual_tamper.md`). The hook only selects regular, non-symlink files under `bazel-bin`, so it cannot reach a source file.
3. **Diff 8c74763..351e732:** only `tool/checks/T-0042-AC4_safety.sh` and the engineer's evidence under `documents/evidence/T-0042/engineer/` changed. No `ide_sync`, BUILD or test change.
4. **`T-0042-AC5_gates.sh` on the synced tree:** PASS (`test //...` 101 of 101, lint, `mc_arch_check`, `rules_fork.sh check`, format, `l10n_check`, fixture suite, T-0032-AC6).
- Issue 1 is closed. Final verdict for T-0042: **PASS**.
