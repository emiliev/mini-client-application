# T-0024: Patch queue for the Bazel rules forks (P3-02)

| Field | Value |
|---|---|
| Status | In Progress |
| Owner | crew: Engineer (Sonnet, worktree) |
| Verifier | crew: Verifier (Opus, fresh) |
| Branch | `fleet/T-0024-patch-queue` |
| Created | 2026-11-24 |
| Depends on | T-0014 (toolchain) |
| Related | [plan 03 KD2, §1, P3-02](../plan/03-bazel-integration.md), ADR-0008, R11, D12 |

## Goal
The mechanism every rules fix and every new codegen shim (retrofit, injectable, BDD) rides on. Patches live in-repo under `third_party/rules_patches/<repo>/NNNN-<slug>.patch`, are applied with `git_override(patches=…)`, and are developed in a local fork checkout wired in by `--override_module` from a git-ignored `.bazelrc.user`.

## Scope
- **In:**
  - `tool/rules_fork.sh` with subcommands:
    - `checkout <repo>`: clone the pinned commit to a fork dir, write `.bazelrc.user` `--override_module`
    - `export <repo>`: turn the fork branch's commits into numbered patches
    - `status`
  - `third_party/rules_patches/{ai_rules_dart,ai_rules_flutter}/` with README conventions.
  - `MODULE.bazel` `git_override(…, patches=[…], patch_strip=1)` wiring that works with zero patches today.
  - One trivial demo patch (e.g. a comment or README line in ai_rules_dart) to prove the round trip, **removed before handoff** unless it's genuinely useful.
- **Out:** real shims (P3-03 to P3-05).

## Acceptance criteria
- **T-0024-AC1:** Given a fork branch with N commits, when `export` runs, then N patches appear, and `git_override(patches=…)` builds the same targets (`//...`) as `--override_module`.
- **T-0024-AC2:** Given a patch that doesn't apply, then the build fails naming the patch.
- **T-0024-AC3:** Given a patch containing a binary hunk, when `export` runs, then it refuses, naming the file. `checkout` writes an absolute path into `.bazelrc.user` (git-ignored).
- **T-0024-AC4:** `tool/test/rules_fork_test.sh` covers AC1 to AC3; `test //...` and lint stay green with the final (zero-patch or real) queue.

## Log
- 2026-11-24: Created and dispatched.

## Outcome
_Pending._
