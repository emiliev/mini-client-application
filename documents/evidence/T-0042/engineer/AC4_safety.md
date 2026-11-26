# T-0042-AC4: tool/ide_sync is safe

| Check | Result | Detail |
|---|---|---|
| A. no sync: build and test //... | PASS | test passed; 27609 output files hashed |
| 1. git status after a sync | PASS | unchanged (29 files synced, all ignored) |
| 1. negative control (stray file) | PASS | git status changed as it must |
| 2a. no synced file is tracked | PASS | 29 checked |
| 2a. negative control (git add -f) | PASS | reported: app/mini_client/lib/src/router/app_routes.g.dart |
| 2b. no BUILD glob picks up a synced file | PASS | 29 synced files, none is a source file of any target |
| 2b. negative control (planted .g.dart in a package without the exclusion) | PASS | the query reports it |
| 3. negative control (planted file in a build) | PASS | the build ran actions, so 'no action' is a real signal |
| B. synced: build and test //... | PASS | both pass |
| 3. synced tree runs no action and no test | PASS | Executed 0 out of 101 tests: 101 tests pass. |
| 3. outputs identical with and without a sync | **FAIL** | 27189a27190
> bazel-bin/utility/mc_prelude/mc_prelude.dart_analyzer_summary.sum-0.params	e9960ba85928f34c1596b8b15d2beaaae90538af51ff0506391fb4234c843f49 |

Test summary (synced tree): Executed 0 out of 101 tests: 101 tests pass.

**FAIL T-0042-AC4**
