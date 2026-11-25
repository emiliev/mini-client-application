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
