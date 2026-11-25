# T-0032 negative controls

Each check below was broken on purpose, run, and then restored. "FAIL" is the
expected result. The byte-identity, cutoff and not-committed controls have
their own reports (linked in the task Outcome).

| Check | Breakage | Result |
|---|---|---|
| `//tool/l10n_check:workspace_gate_test` (T-0025-AC3 gate, now over characters_list) | the German key `charactersListPreviewSeeFullProfile` renamed to `...X` | FAIL: `characters_list: locale de is missing key charactersListPreviewSeeFullProfile`, `... has unknown key charactersListPreviewSeeFullProfileX` |
| `//feature/characters/characters_list:architecture_test` (R15) | `import 'package:flutter/foundation.dart' show kDebugMode;` in `lib/src/navigator/characters_list_navigator.dart` | FAIL: `lib/src/navigator/characters_list_navigator.dart imports Flutter` |
| `//tool/mc_arch_check:bin` and `architecture_test` (R4) | the barrel also exports `CharactersListPage` | `mc_arch_check` exit 1: `[R4] ... barrel exports CharactersListPage ...` ([log](arch_negative_control.log)); `architecture_test` FAILED |
| `T-0032-AC6_matches_build_runner.sh` | bare `@freezed` on `CharacterDto` (F-0025) | FAIL: `character_dto.freezed.dart` DIFFER, 10 of 11 ([report](T-0032-AC6_byte_identity_negative_control.md)) |
| `T-0032-AC6_cutoff.sh` | the retrofit action wired to the package-wide `:_stage` | FAIL: the retrofit part re-ran; 4 bloc files among its inputs ([report](T-0032-AC6_cutoff_negative_control.md)) |
| `T-0032-AC6_generated_not_committed.sh` | a fake `character_dto.g.dart` force-added to the index | FAIL: names the file ([report](T-0032-AC6_generated_not_committed_negative_control.md)) |
| BDD suite | 12 behaviour mutations ([script](mutations.sh)) | all 12 killed by failing scenarios, none by a compile error ([log](mutations.log)) |

Fix round (each fix shown to fail without it):

| Item | Breakage | Result |
|---|---|---|
| 1 AC3 test strength | the Verifier's V4a (an imperative push onto the flow's navigator), re-run with [probe_v4a.py](probe_v4a.py) | the old step: both preview scenarios pass (finding reproduced); the fixed step: "Tapping a character…" and "Going back…" FAIL ([log](probe_v4a.log)) |
| 3 double tap | F1: no "one preview at a time" guard; F2: the preview page not keyed by the id | F1 kills "A second tap while the preview slides in keeps the first character"; F2 kills 3 AC3 scenarios ([log](mutations.log)) |
| 4 `recover()` | F3a: the old step's behaviour (engine `reset()`, harness mirrors kept); F3b: engine-side rules left live | both `harness_test` "T-0032-AC2 recover() …" cases fail with F3a; the first with F3b |
| 5 AC7 gates | `MC_COVERAGE_MIN=100.1` | FAIL on the coverage gate alone ([report](T-0032-AC7_gates_negative_control.md)) |
| 7 team key | F4: `FeatureFlow` not keyed by `initialTeamId` | "T-0032-AC1 a new initialTeamId builds a new flow…" FAILS |
| 8 `.gitignore` | the old broad `**/test/feature/*_test.dart` put back | the not-committed check FAILS: `test/feature/helpers_test.dart` IGNORED ([report](fixround-gitignore-old-pattern.md)) |
| 9 overlay helpers | `tool/checks/T-0032-AC6_overlay_tools.sh` over the c3a5e82 scripts (`MC_OVERLAY_TOOLS`) | FAIL on both cases ([report](fixround-overlay-tools-old.md)) |
| 11 quote styles | F6: the single-quote-only Flutter-import regex | `architecture_test` FAILS |
| 12 synthetic width | F5: names padded to 2 digits only | "T-0032-AC5 a synthetic cast past 99 still pages in name order" FAILS |
