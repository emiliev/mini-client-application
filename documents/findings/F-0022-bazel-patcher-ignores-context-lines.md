# F-0022: Bazel's `git_override` patcher does not verify context lines

| Field | Value |
|---|---|
| Found by | T-0024 Engineer |
| Date | 2026-11-24 |
| Bazel | 9.3.0 |

## What happened
While testing AC2 (a patch that does not apply must fail naming the patch) I tried the obvious breakages in a patch of `ai_rules_dart`:

| Breakage | Result |
|---|---|
| A context line changed to text that is not in the file | Build **succeeds**; the patched file contains the patch's wrong context line. |
| Hunk header line numbers shifted by 9000 | Build **succeeds**; the hunk is applied by content search. |
| Patch targets a file that does not exist | Build **fails**: `Error applying patch <abs path>/0002-....patch: Cannot find file to patch`. The message names the patch. |

So Bazel's built-in Java patcher (used by `git_repository` / `git_override`) is lenient about context and offsets, and strict only about missing files and some malformed hunks.

## Consequences
- A stale patch after a pin bump can apply "successfully" and write wrong content. Do not rely on the build to catch drift.
- `tool/rules_fork.sh checkout` replays the queue with `git am`, which is strict. Run it on the new pin whenever the pin moves (README in `third_party/rules_patches/`).
- AC2 is tested with a patch that targets a missing file (`tool/test/rules_fork_test.sh`).

## Also learned
- Fork dirs must live outside the repo: inside it, their `BUILD` files would join `//...`. The default is `~/.cache/mc-bazel/forks/<worktree>/<repo>` (`MC_FORK_DIR` overrides).
- `exports_files(glob(["*.patch"]))` needs `allow_empty = True`, or an empty queue breaks `//...`.
- Editing a patch file re-fetches the repo (Bazel watches the label), so no `--repo_env` tricks are needed.
