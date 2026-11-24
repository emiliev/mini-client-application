# Rules patch queue (plan 03 KD2, T-0024)

Patches against our two pinned forks, applied by `git_override(patches = [...], patch_strip = 1)` in `MODULE.bazel`.

- `ai_rules_dart/` and `ai_rules_flutter/` hold `NNNN-<slug>.patch`, one file per commit, in `git format-patch` form. Each patch is exactly one upstream PR draft in `documents/upstream/` (D12).
- Never hand-edit a patch. Change the fork commit and re-export.
- The `BUILD.bazel` in each directory exports the patch files so `MODULE.bazel` can name them as labels.

## Workflow

```sh
tool/rules_fork.sh checkout ai_rules_dart   # clone the pin, apply the queue, write .bazelrc.user
# edit and commit in the fork dir (printed by checkout); builds now use the fork via --override_module
tool/rules_fork.sh export ai_rules_dart     # rewrite the queue from the fork's commits (pin..HEAD)
# paste the printed `patches = [...]` into the git_override, delete the fork dir or .bazelrc.user, build
tool/rules_fork.sh status
```

`MC_FORK_DIR` moves the fork dirs (default `~/.cache/mc-bazel/forks/<worktree>/`). They are outside the repo on purpose: a Bazel package inside it would be picked up by `//...`.

## Rules

- `.bazelrc.user` is git-ignored. The committed `MODULE.bazel` must build `//...` without it, so delete the file (or the line) before you hand off.
- Text patches only. `export` refuses a binary change and names the file.
- Bazel's patcher does not verify context lines (F-0022). `checkout` replays the queue with `git am`, which does, so a stale patch is caught there. Run `checkout` on a clean pin after you rebase the queue.
- To move the pin: change `commit` in `MODULE.bazel`, `checkout` (fails naming the first patch that no longer applies), fix in the fork, `export`.
