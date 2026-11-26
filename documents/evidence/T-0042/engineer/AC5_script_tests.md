# T-0042-AC5: tool/ide_sync script tests (fixtures)

| Test | Result |
|---|---|
| harness negative control: expect() fails on a wrong expectation | PASS |
| 1. first sync copies every output (copied=4) | PASS |
| 1. the copies hold the source bytes | PASS |
| 1. the copies are writable (Bazel outputs are read-only) | PASS |
| 1. the manifest lists the 4 files, sorted | PASS |
| 1. the manifest is sorted | PASS |
| 1. git status is clean after the sync | PASS |
| 2. second sync copies 0 files (unchanged=4) | PASS |
| 2. mtimes are unchanged | PASS |
| 3. a changed output re-copies only that file | PASS |
| 3. the new bytes are in place | PASS |
| 4. a file no longer produced is deleted | PASS |
| 4. and leaves the manifest | PASS |
| 4. the other outputs stay | PASS |
| 5. a tracked destination is refused (exit 1) | PASS |
| 5. REFUSED names the file | PASS |
| 5. nothing is written when any path is refused | PASS |
| 5. the tracked file keeps its content | PASS |
| 6. a destination that is not git-ignored is refused | PASS |
| 6. REFUSED says a commit would pick it up | PASS |
| 6. and nothing is written | PASS |
| 7. a path in the R28 fallback manifest is not written | PASS |
| 7. the other path is | PASS |
| 7. skipped=1 | PASS |
| 7. the fallback path is not in the manifest | PASS |
| 8. --link makes a symlink to the Bazel output | PASS |
| 8. a second --link sync changes nothing | PASS |
| 8. copy mode replaces the link by a regular file | PASS |
| 9. a scoped sync keeps manifest entries of other packages | PASS |
| 9. and does not delete files outside its scope | PASS |
| 9. a full sync deletes it (not produced any more) | PASS |
| 9. package arguments accept a trailing slash and //pkg/... | PASS |
| 10. a tracked file in the manifest is not deleted | PASS |
| 11. --clean deletes the synced files and the manifest | PASS |
| 11. --clean keeps tracked sources | PASS |
| 12. --env dev writes app/mini_client/assets/app_config.json | PASS |
| 12. the asset is git-ignored (git status clean) | PASS |
| 12. a run without --env keeps the asset | PASS |
| 12. and keeps it in the manifest | PASS |
| 12. --env e2e switches the asset to e2e.json | PASS |
| 12. an unknown environment is refused (exit 2) | PASS |
| 13. an unknown option is refused (exit 2) | PASS |
| 13. an unknown package is refused (exit 2) | PASS |
| 14. --watch re-syncs within 5 s of a source edit | PASS |

**PASS T-0042-AC5-script-tests**
