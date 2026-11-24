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
- Bazel's patcher is lenient and can silently drop a stale hunk (F-0022). `check` and `checkout` replay the queue with `git am`, which is strict.
- Run `tool/rules_fork.sh check` before merging any queue change (strict `git am` replay on the pin; names the first bad patch).
- To move the pin: change `commit` in `MODULE.bazel`, `checkout` (fails naming the first patch that no longer applies), fix in the fork, `export`.
- **No fork `MODULE.bazel.lock` in queue patches** (TL decision, 2026-11-24). Our builds never read a dependency's lockfile, and a lock hunk goes stale silently when patches stack (the T-0029 Verifier showed a wrong hash surviving `check`). Run fork-side tests with `--lockfile_mode=update`; an upstream PR draft regenerates the fork lock for that PR only.
- When patches touch the same file (for example `dart/ext/pubspec.yaml`, `pubspec.lock`, `docs/ext.md`), the later task rebases its fork commit onto the merged queue, **re-resolves** `dart/ext/pubspec.lock` (never hand-merge it), re-exports, and runs `check`.
