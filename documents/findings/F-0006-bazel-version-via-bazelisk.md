# F-0006: Bazel 9.3.0 runs through the unlinked Homebrew bazelisk; `tool/bazelw` is mandatory

- **Date:** 2026-11-23
- **Author:** crew: Engineer (T-0014)
- **Type:** Environment
- **Related:** T-0014, R18, plan 03 §1.3, R11 (plan 03 risk register)

## Summary
bazelisk **1.29.0** is installed at `/opt/homebrew/opt/bazelisk/bin/bazelisk` but not linked (it conflicts with the linked `bazel` formula, **9.2.0**). Nothing was installed or relinked. `tool/bazelw` execs that bazelisk, which finds `.bazelversion` (`9.3.0`) by walking up from any directory inside the repo. Bare `bazel` on PATH is still Homebrew 9.2.0, and would churn `MODULE.bazel.lock`.

## Evidence
| Check | Result |
|---|---|
| `ls /opt/homebrew/opt/bazelisk/bin/` | `bazelisk` (6.8 MB) and a `bazel -> bazelisk` symlink; neither is on PATH |
| `which bazel` / `bazel --version` | `/opt/homebrew/bin/bazel`, `bazel 9.2.0 Homebrew` |
| bazelisk run **outside** the repo (no `.bazelversion`) | downloaded **9.3.3** (latest release), about 18 s |
| `tool/bazelw version` in the repo | downloaded 9.3.0 once (about 36 s), then `Build label: 9.3.0` |
| Downloads land in | `~/Library/Caches/bazelisk/` (shared by every worktree) |

## Gotchas
1. **Never run bare `bazel` or bare `bazelisk` here.** Bare `bazel` is 9.2.0; bare bazelisk outside the repo picks the newest release. Both change the lockfile or the server.
2. `tool/bazelw` does **not** change directory (code review, T-0014). Relative labels and relative file arguments resolve against your shell's cwd, as with plain Bazel. Relative file flags such as `--execution_log_compact_file=x.zst` land in the cwd, not the workspace root, which was checked on 9.3.0. In rc files, use `%workspace%/…`, which Bazel 9.3.0 expands in flag values (used by `--config=profile`).
3. `tool/bazelw --budget16 <cmd> …` adds `--host_jvm_args=-Xmx3g` (a startup option, which a `--config` cannot carry) and `--config=budget16` right after the command. `--budget16` is recognised only among the leading startup options. Other startup options may come before or after it (`tool/bazelw --output_base=/x --budget16 test //…`). After the command or `--` it is passed through untouched. The first version inserted `--config` after the first argument, even when that was a startup option. The code review and the Verifier both hit that, and `tool/test/bazelw_test.sh` (8 cases, stub bazelisk) now covers it. Changing startup options restarts the Bazel server, which throws away the analysis cache and warm workers.
4. `MC_BAZELISK=/path` overrides the bazelisk location; if it is missing, `tool/bazelw` exits 2 with an install hint (`brew install bazelisk`).
