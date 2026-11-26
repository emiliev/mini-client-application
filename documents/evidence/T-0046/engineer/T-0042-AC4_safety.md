# T-0042-AC4: tool/ide_sync is safe

| Check | Result | Detail |
|---|---|---|
| A. no sync: build and test //... | PASS | test passed; 46767 output files hashed |
| 1. git status after a sync | PASS | unchanged (45 files synced, all ignored) |
| 1. negative control (stray file) | PASS | git status changed as it must |
| 2a. no synced file is tracked | PASS | 45 checked |
| 2a. negative control (git add -f) | PASS | reported: app/mini_client/lib/src/router/app_routes.g.dart |
| 2b. no BUILD glob picks up a synced file | PASS | 45 synced files and 12 gen-l10n files, none is a source file of any target |
| 2b. negative control (planted .g.dart in a package without the exclusion) | PASS | the query reports it |
| B. synced: build and test //... | PASS | both pass |
| 3. synced tree runs 0 actions and 0 tests | PASS | Executed 0 out of 134 tests: 134 tests pass. |
| 3. every unsynced output is in the synced run with the same hash | PASS | 46767 files, same bytes |
| 3. negative control (planted file in a build) | PASS | the build ran actions, so 'no action' is a real signal |

Files only in the synced run (0): none

Test summary (synced tree): Executed 0 out of 134 tests: 134 tests pass.

**PASS T-0042-AC4**
