# T-0062 verification report (fresh Verifier, Sonnet tier)

Verdict: **PASS**. Commit under test: `ff78508`. Everything below was re-derived; none of it comes from the engineer's logs.

| AC | Result | Evidence |
|---|---|---|
| AC1 bundle id | PASS | The prepared project (`prepare_pub_project.sh`) holds `com.emiliev.miniclient` in all 6 `PRODUCT_BUNDLE_IDENTIFIER` lines (3 are `...RunnerTests`). `e2e_ios.sh` ran `not_found_cold_test` on `mc-T-0062-verifier-*` and passed (`verifier/AC1_e2e-summary.md`). The runner uninstalls the app at the end of `flutter drive`, so I re-ran with `--keep-app-running`. `simctl listapps` then showed `CFBundleIdentifier = "com.emiliev.miniclient"` and 0 matches for `com.emiliev.miniClient`. `get_app_container com.emiliev.miniclient` resolved. `grep -rn miniClient tool app` finds nothing. The `ide_sync` rewrite is the same `sed`, applied only when a pbxproj exists, and `T-0042-AC5_script_tests.sh` passes (rc 0). |
| AC2 format gate | PASS | In a throwaway worktree at `ff78508` with no `.dart_tool`, the gate ran `pub get --offline`, formatted 899 files, 0 changed, rc 0. Unformatted line in `tool/loc/lib/count.dart`: rc 1. Unformatted line in `third_party/flow_builder`: rc 0. Unformatted `.dart` file under `documents/`: rc 0. All reverted. The final gate run passed and `T-0035-AC4_provenance.sh` passed. 13 `.dart` to `.dart.txt` renames (git rename detection). A search of `documents`, `tool` and `app` for each old name found no stale reference. The `.dart` files still under `documents/` were not in scope (the gate excludes `documents/`). |
| AC3 roles, raw tree | PASS | `tool/test/e2e_ios_test.sh`: 23 passed, 0 failed (733 s; `verifier/AC3_e2e_ios_test_tail.log`). The 3 `T-0062-AC3` tests include the `reverify` role. Run by hand on the raw `app/mini_client` with role `reverify`: exit 2 with the "has no ios/Runner.xcodeproj ... tool/e2e/prepare_pub_project.sh" message. No `mc-T-0062` simulator is left. |
| AC4 overlays | PASS | Own mutations with sed (`verifier/AC4_mutations_verifier.log`): baseline passes. `pop` in both handle callbacks, only the tap, and only the semantics each FAIL. A filtered run (`--test_filter=T-0062-AC4`) with the tap mutant showed the new `T-0062-AC4` handle test FAILING. Toast 3 s and 5 s both FAIL, on the duration expectation and the 3.9 s/4.1 s test. Sources restored; tree clean. 50 runs of `overlays_test` with `--runs_per_test=50`: all pass, 0 failures. |
| AC5 gates | PASS | `test --lockfile_mode=error //...`: 191/191 pass. `build --config=lint //...` OK. `bazelw run //tool/mc_arch_check:bin`: OK. `rules_fork.sh check`: OK. `git diff --stat origin/main...ff78508 -- app feature utility spike` shows only `overlays_test.dart` (+64). No product `lib/` change. |

## Merge check
`git merge --no-commit --no-ff origin/main` merged cleanly, with no conflicts. On the merged tree:
- `test --lockfile_mode=error //...`: 201/201 pass.
- The format gate: rc 0 (1013 files, 0 changed). This includes `feature/store/store_home`.

The merge was aborted afterwards and the worktree is back at `ff78508`.

## Notes (not defects)
- I ran e2e on one target only, as asked. The runner's own default uninstalls the app at the end, so checking `listapps` after a plain run finds nothing. Use `--keep-app-running` for that check.
- The first `listapps` attempt ran on a plain run, so that simulator was deleted and the check was redone on a second one.
- Simulators `mc-T-0062-verifier-19484` and `-20798` are both deleted. The throwaway worktree `/tmp/mc-T-0062-verifier/wt` is removed in cleanup, and the Bazel output base is shut down.

Defects: none.
