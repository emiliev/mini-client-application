# T-0042-AC4: tool/ide_sync is safe

| Check | Result | Detail |
|---|---|---|
| A. no sync: build and test //... | PASS | test passed; 33965 output files hashed |
| 1. git status after a sync | PASS | unchanged (23 files synced, all ignored) |
| 1. negative control (stray file) | PASS | git status changed as it must |
| 2a. no synced file is tracked | PASS | 23 checked |
| 2a. negative control (git add -f) | PASS | reported: app/mini_client/lib/src/router/app_routes.g.dart |
| 2b. no BUILD glob picks up a synced file | PASS | 23 synced files and 6 gen-l10n files, none is a source file of any target |
| 2b. negative control (planted .g.dart in a package without the exclusion) | PASS | the query reports it |
| B. synced: build and test //... | PASS | both pass |
| 3. synced tree runs no action and no test | PASS | Executed 0 out of 101 tests: 101 tests pass. |
| 3. outputs identical with and without a sync | PASS | 33965 files, same bytes |
| 3. negative control (planted file in a build) | PASS | the build ran actions, so 'no action' is a real signal |

Test summary (synced tree): Executed 0 out of 101 tests: 101 tests pass.

**PASS T-0042-AC4**
