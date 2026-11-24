# T-0024: Patch queue for the Bazel rules forks (P3-02)

| Field | Value |
|---|---|
| Status | Ready for Verifier |
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
- 2026-11-24: Engineer: implemented `tool/rules_fork.sh`, `third_party/rules_patches/`, `MODULE.bazel` wiring (empty queue, `patch_strip = 1`), `tool/test/rules_fork_test.sh`, F-0022. Also proven by hand on the real `ai_rules_dart` pin with a 2-commit demo (override and patches built `//...` with identical `query //...`, 125 targets); the demo was removed, the queue ships empty.

## Outcome
Evidence: `documents/evidence/T-0024/engineer/` (test, lint, arch, rules_fork_test logs).

| AC | Test (`tool/test/rules_fork_test.sh`) |
|---|---|
| AC1 | `T-0024-AC1_export_writes_one_patch_per_commit`, `T-0024-AC1_git_override_patches_build_same_as_override_module` |
| AC2 | `T-0024-AC2_unappliable_patch_fails_naming_it`, `T-0024-AC2_checkout_rejects_unappliable_queued_patch` |
| AC3 | `T-0024-AC3_export_refuses_binary_hunk_naming_file`, `T-0024-AC3_checkout_writes_absolute_override`, `T-0024-AC3_bazelrc_user_is_gitignored` |
| AC4 | the script itself, plus `T-0024-AC4_committed_queue_matches_module_bazel`; `test //...` 39/39, lint and `mc_arch_check` green with the empty queue |

Notes for the Verifier and TL:
- The test uses a local fake upstream module and a throwaway workspace and output base, so it needs no network.
- F-0022: Bazel's patcher ignores context lines and offsets. AC2 is exercised with a patch whose target file is missing; `checkout` (git am) is the strict check.
- Fork dirs default to `~/.cache/mc-bazel/forks/<worktree>/<repo>`, outside the repo so their BUILD files stay out of `//...`.
- Follow-ups: a CI check that every `*.patch` is listed in `MODULE.bazel` (only `status` and the AC4 test compare today); P3-03 should start from `checkout`.

### Review fixes (code-review, 4 important + nits)
`tool/rules_fork.sh` now: (1) rewrites only the `# >>> / <<< rules_fork.sh` block of `.bazelrc.user` (test `AC3_checkout_preserves_user_bazelrc_lines`); (2) checks binaries per commit via `git log --numstat` and `--no-binary` (`AC3_export_refuses_binary_hunk_naming_file` with a pre-seeded patch that must survive, `AC3_export_refuses_binary_added_then_removed`); (3) `export` refuses an open `git am`/rebase, a HEAD off branch `fork`, and fewer commits than queued patches unless `--force` (`AC2_export_refuses_after_failed_checkout`, `AC1_export_refuses_detached_head`, `AC1_export_refuses_dropping_patches_without_force`); (4) refuses merge commits (`AC1_export_refuses_merge_commits`). Nits: glob arrays for patch paths, fork dir keyed on basename plus a hash of the absolute root, `status` compares names and order and exits non-zero on mismatch (`AC4_status_detects_order_mismatch`, `AC4_status_accepts_matching_order`), ACTIVE only for uncommented lines (`AC4_status_ignores_commented_override`), test has no BSD-only `sed -i ''`. Re-run: `rules_fork_test.sh` 17/17, `bazelw_test.sh` 8/8, `test //...` 39/39, lint and `mc_arch_check` green.
