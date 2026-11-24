# F-0022: Bazel's `git_override` patcher can accept or drop a stale patch

| Field | Value |
|---|---|
| Found by | T-0024 Engineer; corrected by the T-0024 Verifier (`documents/evidence/T-0024/verification-report.md`) |
| Date | 2026-11-24 |
| Bazel | 9.3.0 |

## What happened
Bazel's built-in patcher (`git_repository` / `git_override`) uses java-diff-utils `applyFuzzy`. It is lenient about drift. Observed on the real `ai_rules_dart` pin:

| Drift in the patch | Bazel build | `git am` (`checkout`, `check`) |
|---|---|---|
| Inner context line (next to the change) wrong, mid-file | Fails, names the patch | Rejects, names the patch |
| Outer context line wrong, mid-file | **Succeeds**: applied with fuzz, the real line is kept | Rejects, names the patch |
| Context line wrong, pure addition at end of file | **Succeeds and silently drops the hunk**: the fetched tree is byte-identical to the pristine pin | Rejects, names the patch |
| Removed line wrong, at end of file | Fails with a Bazel crash (`IllegalArgumentException` in `ChangeDelta.applyFuzzyToAt`); **the patch is not named** | Rejects, names the patch |
| Patch targets a file that does not exist | Fails, names the patch | Rejects |
| Hunk header offset shifted | Succeeds (found by content search) | Applies with an offset |

(An earlier version of this table claimed the wrong context line ends up in the patched file; the Verifier could not reproduce that.)

## Consequences
- A stale patch after a pin bump can build green and silently lose its change. Never rely on the build to catch drift.
- `tool/rules_fork.sh check [<repo>]` replays the queue with `git am` on the pin and fails naming the first bad patch. **Run it before merging any queue change** (the TL wires it into the verify gate). `checkout` is strict for the same reason.
- AC2 tests: `tool/test/rules_fork_test.sh` (`AC2_check_rejects_wrong_context_line_at_eof`, `AC2_check_rejects_wrong_removed_line_at_eof`, missing-file build case).

## Also learned
- Fork dirs must live outside the repo: inside it, their `BUILD` files would join `//...`. Default `~/.cache/mc-bazel/forks/<worktree>-<hash>/<repo>` (`MC_FORK_DIR` overrides).
- `exports_files(glob(["*.patch"]))` needs `allow_empty = True`, or an empty queue breaks `//...`.
- Editing a patch file re-fetches the repo (Bazel watches the label).
