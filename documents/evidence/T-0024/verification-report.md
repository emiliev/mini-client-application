# Verification report: T-0024, Patch queue for the Bazel rules forks

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Simulator:** none (tooling task, no UI)
- **Output base:** `/tmp/mc-ob-T-0024-verifier` (rounds 1 and 2), `/tmp/mc-ob-T-0024-verifier-b` (round 3). Shut down at the end of each round.

# Round 3: re-verification at `543e414` (current verdict)

- **Branch / commit verified:** `fleet/T-0024-patch-queue` @ `543e414`, verified on `fleet/T-0024-verify3`
- **Change since round 2:** the open-`git am` guard uses `rev-parse --path-format=absolute --git-path`. Its test runs from the repo root and asserts the exact refusal. `.gitignore` adds `.bazelrc.user.tmp`.
- **Verdict:** **PASS**. All four ACs pass, and round 2's Issues 1 to 3 are resolved.
- **Evidence:** `documents/evidence/T-0024/verifier3/`

| Check | Result | Evidence |
|---|---|---|
| My round-2 repro on the real `ai_rules_dart` pin. Run from the repo root, with `.git/rebase-apply` present, 1 fork commit and 0 queued patches (so the drop-patches guard cannot fire). | **Refused**, exit 1: `unfinished git am/rebase in <fork> (rebase-apply exists)`. The queue is untouched. | `export_open_am.log` |
| Mutation: `tool/rules_fork.sh` from `7fd9b02` (old relative-path guard) run against the new test | `T-0024-AC2_export_refuses_after_failed_checkout` **FAILS**: 20 passed, 1 failed. The test now catches the bug. Script restored afterwards. | `mutation_old_guard.log` |
| `.bazelrc.user.tmp` ignored | `git check-ignore`: `.gitignore:27` | |
| `tool/test/rules_fork_test.sh` | 21 passed, 0 failed | `rules_fork_test.log` |
| `tool/test/bazelw_test.sh` | 8 passed, 0 failed | `bazelw_test.log` |
| `tool/bazelw test --nocache_test_results //...` | 39/39 pass | `test.log` |
| `build --config=lint //...` / `run //tool/mc_arch_check:bin` | green / OK | `lint.log`, `arch.log` |
| `rules_fork.sh status` / `check` on the committed (empty) queue | exit 0 / exit 0 | `status.log`, `check.log` |

| AC | Result |
|---|---|
| T-0024-AC1 | **PASS** (round 2 evidence still holds; no change to that code) |
| T-0024-AC2 | **PASS** (plus the open-am guard is now effective and tested) |
| T-0024-AC3 | **PASS** |
| T-0024-AC4 | **PASS** |

- Test integrity: one test was tightened (an assertion made stricter, not weakened). Nothing was deleted or skipped, and no suppressions were added.
- Still open, for the TL: wire `rules_fork.sh check` into the verify gate (round 2, Note 4).
- Cleaned up: fork dir, `.bazelrc.user`, and the `git am` state. Server shut down. Nothing pushed.

# Round 2: re-verification at `7fd9b02`

- **Branch / commit verified:** `fleet/T-0024-patch-queue` @ `7fd9b02` (`3f04d95` review fixes, plus `7fd9b02` `check` and the F-0022 correction), verified on `fleet/T-0024-verify2`
- **Verdict:** **FAIL**. AC1 to AC4 now pass, and the round-1 AC3 issue is fixed. But one of the review fixes I was asked to check does not work: `export`'s "unfinished `git am`/rebase" guard is dead code when the script runs from the repo root (the normal case), and the test meant to protect it passes for a different reason.
- **Evidence:** `documents/evidence/T-0024/verifier2/`

## Gates re-run independently
| Gate | Command | Result |
|---|---|---|
| Unit (tool) | `tool/test/rules_fork_test.sh` | 21 passed, 0 failed, `rules_fork_test.log` |
| Unit (tool) | `tool/test/bazelw_test.sh` | 8 passed, 0 failed |
| Tests | `tool/bazelw test --nocache_test_results //...` | 39/39 pass |
| Lint | `tool/bazelw build --config=lint //...` | green |
| Arch | `tool/bazelw run //tool/mc_arch_check:bin` | OK |
| Final state | `query //...`, `build //...`, `status`, `check` after the revert | 125 targets, the same as the baseline. Build green. `status`: names and order match. `check`: both queues empty, OK. |

## Real-pin round trip (`ai_rules_dart` @ `e7163aa`)
| Step | Result |
|---|---|
| `checkout` with a hand-written `.bazelrc.user` (3 user lines) | User lines kept, and the managed block was appended. I then added a line *after* the block and re-ran `checkout` (fresh fork): lines before and after the block both survive (`bazelrc_user_after_checkouts.txt`). The fork dir is now `~/.cache/mc-bazel/forks/<worktree>-<hash>/`, outside the repo. |
| 1-line commit in the fork, `query //...` with the override | identical to the baseline (125) |
| `export`, which wrote `0001-...patch`, listed in `MODULE.bazel` | `query //...` with override plus patch, and with the patch only: identical (125). `build //spike/...` green, and the fetched `defs.bzl` carries the marker. |
| `status` / `check` (good queue) | `status` exit 0, "patches match the queue (names and order)". `check` exit 0, "1 patch(es) apply strictly" (`check_good.log`). The same result from a fresh pin-cache fetch over the network (`MC_FORK_DIR`/`MC_PIN_CACHE` set to empty scratch dirs, `check_good_pin_cache.log`). |
| Revert | `MODULE.bazel`, patches, `.bazelrc.user`, fork dir and scratch pin cache removed. `git status` is clean apart from this evidence. |

## Requested checks
| Check | Result | Evidence |
|---|---|---|
| **AC3**: binary added in one commit and deleted in a later one | **Refused**, naming `dart/icon.bin`; the queue is untouched. Fixed. | `binary_add_remove_export.log` |
| **`check`**: wrong context line at EOF (the patch Bazel builds green while dropping the hunk) | **Fails** (exit 1), naming `0001-...patch` | `check_eof_context.log` |
| **`check`**: wrong removed line at EOF (the patch Bazel crashes on, unnamed) | **Fails** (exit 1), naming `0001-...patch` | `check_eof_removal.log` |
| **`check`**: good queue | **Passes** (fork-dir source and pin-cache source) | `check_good.log`, `check_good_pin_cache.log` |
| `.bazelrc.user` lines outside the markers survive `checkout` | **Pass** | `bazelrc_user_after_checkouts.txt` |
| `export` refuses dropping patches without `--force` | **Pass**: fork has 1 commit, queue has 2, so it is refused and the queue is kept. `--force` exports 1. | `export_drop_noforce.log`, `export_drop_force.log` |
| `export` refuses a detached HEAD | **Pass** | `export_detached.log` |
| `export` refuses merge commits | **Pass** (`--no-ff` merge of a side branch, refused naming the merge SHA) | `export_merge.log` |
| `export` refuses an open `git am` | **FAIL**: exit 0, and it exported while `.git/rebase-apply` existed. The same command run from *inside* the fork dir refuses correctly. | `export_open_am.log`, `export_open_am_from_fork_dir.log` |
| `status` compares names and order | **Pass**: listing `0002, 0001` against the queue `0001, 0002` gives `MISMATCH`, exit 1 | `status_order_mismatch.log` |
| F-0022 table corrected | **Pass**: it matches my round-1 observations, adds `check`, and notes the correction. | `documents/findings/F-0022-*.md` |

## Acceptance criteria (round 2)
| AC | Result | Note |
|---|---|---|
| T-0024-AC1 | **PASS** | Real-pin round trip; 1 commit gives 1 patch; `query //...` identical under the override, both, and the patch only. The merge, detached-HEAD and `--force` guards work. |
| T-0024-AC2 | **PASS** | The build fails naming the patch for missing-file and mid-file mismatches (round 1). `check` now catches both EOF drift shapes that Bazel misses, naming the patch. |
| T-0024-AC3 | **PASS** | Per-commit binary check plus `--no-binary` and a grep of the exported files. The add-then-delete repro is refused. The absolute override and git-ignore still pass. |
| T-0024-AC4 | **PASS** | 21/21 tool tests, 39/39 `test //...`, lint and arch green with the empty queue. |

## Issues found (round 2)
1. **(Medium, blocks PASS) The open-`git am` guard in `export` never fires from the repo root.**
   - Where: `tool/rules_fork.sh` `cmd_export`. `git -C "$dir" rev-parse --git-path rebase-apply` prints a path relative to the fork (`.git/rebase-apply`), and `[[ -e … ]]` then tests it against the caller's cwd.
   - Reproduce: `checkout`, commit, run `git am` with a patch that fails (no work-tree changes are left), then `tool/rules_fork.sh export ai_rules_dart` from the repo root. It exits 0 and exports.
   - Fix: `git -C "$dir" rev-parse --path-format=absolute --git-path "$g"`, or prefix `"$dir/"` when the path is relative.
2. **(Medium, test integrity) `T-0024-AC2_export_refuses_after_failed_checkout` passes for the wrong reason.**
   - It accepts either `"git am"` or `"queue holds"` in the output. In its scenario the fork has fewer commits than the queue, so the drop-patches guard fires and hides Issue 1.
   - Fix: assert the `git am`/rebase message only, in a scenario where commits ≥ queued patches.
3. **(Nit)** `write_override` writes `.bazelrc.user.tmp` and then renames it. `.gitignore` covers only `.bazelrc.user`, so an interrupted run leaves an un-ignored file. Add `.bazelrc.user*` or `.bazelrc.user.tmp`.
4. **(Note)** `check` is not wired into any gate yet. The README says the TL wires it into the verify gate. This is fine for this task; it is tracked as TL work.

## Notes for the Tech Lead (round 2)
- Issues 1 and 2 are a one-line fix plus a tightened test. Re-verifying only the open-`am` guard (and the 21 tool tests) should be enough afterwards.
- Cleaned up: fork dir `~/.cache/mc-bazel/forks/agent-ad69b6af6d5e7192e-001753ca99`, the scratch pin cache, `.bazelrc.user`, and the `MODULE.bazel` and queue edits. Server shut down. I didn't touch `/Users/emililiev/orca/workspaces/mini-client/tang`.

---

# Round 1: verification at `3fb08ff` (kept for history)

- **Branch / commit verified:** `fleet/T-0024-patch-queue` @ `3fb08ff` (verified on `fleet/T-0024-verify`, report commit `6e0145f`)
- **Verdict:** **FAIL** (AC3: `export` can write a patch that contains a binary hunk. Everything else passes.)

## Gates re-run independently
Logs are in `documents/evidence/T-0024/verifier/`.

| Gate | Command | Result |
|---|---|---|
| Unit (tool) | `tool/test/rules_fork_test.sh` | 8 passed, 0 failed (14 s), `rules_fork_test.log` |
| Unit (tool) | `tool/test/bazelw_test.sh` | 8 passed, 0 failed, `bazelw_test.log` |
| Tests | `tool/bazelw test --nocache_test_results //...` | 39/39 pass, `test.log` |
| Lint | `tool/bazelw build --config=lint //...` | green, `lint.log` |
| Arch | `tool/bazelw run //tool/mc_arch_check:bin` | `mc_arch_check: OK`, `arch.log` |
| Final state | `query //...` / `build //...` after the revert | 125 targets, the same as the baseline; build green, `build_all_final.log` |

## Real round trip on the `ai_rules_dart` pin (`e7163aa`)
| Step | Result |
|---|---|
| Baseline `query //...` (no override, empty queue) | 125 targets |
| `rules_fork.sh checkout ai_rules_dart` | Fork in `~/.cache/mc-bazel/forks/agent-ad69b6af6d5e7192e/ai_rules_dart`, outside the repo. `.bazelrc.user` has an absolute `--override_module`. `mod show_repo @rules_dart` shows `local_repository(path = <fork>)`. |
| 1-line commit in the fork (comment appended to `dart/defs.bzl`), then `query //...` with the override | 125 targets, identical to the baseline |
| `export`, which wrote `0001-Add-verifier-marker-comment-to-defs.bzl.patch` (one patch per commit), pasted into `MODULE.bazel` | `query //...` with both the override and the patch: identical, 125 |
| `.bazelrc.user` removed (patch only) | `query //...` identical, 125. `mod show_repo` shows `git_repository(patches = [Label(...0001...)])`. The fetched `defs.bzl` contains the marker. `build //spike/...` and `build //...` are green (`spike_build_with_patch.log`, `build_all_with_patch.log`). |
| Revert (`MODULE.bazel`, patches, `.bazelrc.user`, fork dir) | `git status` is clean apart from this evidence. `git check-ignore -v .bazelrc.user` gives `.gitignore:3`. `.bazelrc.user` has never been committed. The queue ships empty. |

## AC2 / F-0022: stale patches on the real pin
| Breakage (real `defs.bzl`) | `build //spike/...` | `checkout` (`git am`) |
|---|---|---|
| Target file missing (`dart/nope.bzl`) | **fails, names the patch** (`missing_file_build.log`) | n/a |
| Removal (`-`) line no longer in the file, mid-file | **fails, names the patch** (`CONTENT_DOES_NOT_MATCH_TARGET`, `stale_removal_midfile_build.log`) | n/a |
| Inner context line (next to the change) wrong, mid-file | **fails, names the patch** (`stale_context_midfile_build.log`) | n/a |
| Outer context line wrong, mid-file | **succeeds**. Applied with fuzz, and the real line is kept (`stale_outer_context_build.log`). | **rejects, names the patch** (`stale_outer_context_checkout.log`) |
| Context line wrong, pure addition at EOF | **succeeds, and the hunk is silently dropped**. The fetched tree is byte-identical to the pristine pin (`stale_context_build.log`, checked with `diff -r` against the repo-contents cache). | **rejects, names the patch** (`stale_context_checkout.log`) |
| Removal line wrong, at EOF | **fails with a Bazel crash** (`IllegalArgumentException` in java-diff-utils `ChangeDelta.applyFuzzyToAt`). **The patch is not named.** (`stale_removal_build.log`) | not tried |

So the claim holds: Bazel's patcher can accept a stale patch, and `checkout` is strict. Bazel uses java-diff-utils `applyFuzzy`. The table in F-0022 is not quite accurate, though:
- I could not reproduce "the patched file contains the patch's wrong context line". Outer-context drift keeps the real line.
- Inner-context drift fails cleanly.
- The worst case is the one F-0022 doesn't list: an EOF hunk dropped without a word.
- The EOF crash case doesn't name the patch.

## Acceptance criteria
| AC | Scenario (short) | Mapped test(s) / checkpoint | Test really asserts the AC? | Result |
|---|---|---|---|---|
| T-0024-AC1 | N commits give N patches; `patches` builds the same as `--override_module` | `T-0024-AC1_export_writes_one_patch_per_commit`, `T-0024-AC1_git_override_patches_build_same_as_override_module`, plus the real round trip above | Yes, on a fake module (2 commits, 2 patches, identical output bytes). On the real pin, `query //...` gave the same 125 targets under the override, override plus patch, and patch only. | **PASS** |
| T-0024-AC2 | A patch that doesn't apply fails the build, naming the patch | `T-0024-AC2_unappliable_patch_fails_naming_it` (missing file), `T-0024-AC2_checkout_rejects_unappliable_queued_patch` | Yes, for the missing-file case. On the real pin, the missing-file and mid-file content mismatch cases fail naming the patch. Two drift shapes get past the build (see above), but `checkout` catches them. This is a Bazel limitation, documented in F-0022 and covered by the strict `checkout` step. | **PASS** (caveat: the build alone doesn't catch every drift; see Issue 2) |
| T-0024-AC3 | `export` refuses a binary hunk, naming the file; `checkout` writes an absolute path into git-ignored `.bazelrc.user` | `T-0024-AC3_export_refuses_binary_hunk_naming_file`, `..._checkout_writes_absolute_override`, `..._bazelrc_user_is_gitignored` | Partly. On the real fork, a binary added in the last commit is refused, naming `dart/icon.bin`, and the queue is left untouched (`binary_export.log`). **But a binary added in one commit and deleted in a later one is exported**: `0002-Add-binary-icon.patch` contains a `GIT binary patch` hunk, export exits 0, and the queue then breaks the build (`binary_add_remove_export.log`, `binary_queue_build.log`). The absolute path and git-ignore parts pass. | **FAIL** |
| T-0024-AC4 | `rules_fork_test.sh` covers AC1 to AC3; `test //...` and lint green with the final queue | the script, plus `T-0024-AC4_committed_queue_matches_module_bazel` | Yes. The queue ships empty, the gates are green, and `//...` is unchanged. The AC3 test doesn't cover the multi-commit binary case. | **PASS** (needs a new test with the AC3 fix) |

## Test-integrity audit
- Tests deleted, skipped or weakened: none (new test file only).
- Lint suppressions added: none.
- Golden files updated: none.
- `MODULE.bazel.lock` is untouched by the branch. A lockfile diff (protobuf and pybind11 extension entries) appeared only after my diagnostic `bazel mod show_repo`, and I reverted it. The normal `query`, `build` and `test` runs leave the lockfile clean.

## Hygiene
- The queue ships empty: both `third_party/rules_patches/*/` contain only `BUILD.bazel` (`exports_files(glob(["*.patch"], allow_empty = True))`).
- The `MODULE.bazel` wiring (`patch_strip = 1`, empty `patches = []`) builds and queries `//...` exactly as before (125 targets, 39/39 tests).
- The fork dirs default to `~/.cache/mc-bazel/forks/<worktree>/<repo>`, outside the repo. I deleted mine.
- `checkout` writes no `.bazelrc.user` when a queued patch fails to apply (good). It leaves the fork mid-`git am`, and says so.

## Issues found
1. **(Medium, AC3 fail) `export` checks only the net diff `pin..HEAD`, not each commit.**
   - Where: `tool/rules_fork.sh` `cmd_export`, `git diff --numstat "$commit" HEAD`.
   - A binary that is added and later deleted, or changed and then reverted, cancels out in the net diff. The per-commit patches then carry `GIT binary patch` hunks, and Bazel fails with a misleading "Cannot find file to patch".
   - Reproduce: `checkout`, commit a binary file, commit its deletion, `export`. The exit code is 0, and `0002-*.patch` contains a binary hunk.
   - Fix: check per commit, for example `git log --numstat --format= "$commit..HEAD" | awk -F'\t' '$1=="-" && $2=="-" {print $3}'`, or grep the files in `$out` for `^GIT binary patch$` before copying them. Then add a test named `T-0024-AC3_...` for the add-then-delete sequence.
2. **(Low, docs) F-0022's table doesn't match what I observed on Bazel 9.3.0** (see the AC2 table).
   - Amend it to say: outer-context drift is fuzz-applied; inner-context and removal drift fail naming the patch; an EOF context-only drift silently drops the hunk; an EOF removal mismatch crashes Bazel without naming the patch.
   - The conclusion still stands, and is stronger: `checkout` is the only reliable drift check.
3. **(Low, follow-up) Nothing enforces the strict check.**
   - The README tells people to run `checkout` after a pin move, but no gate does it.
   - Suggest a `rules_fork.sh check <repo>` (clone the pin into a temp dir, `git am` the queue, delete it) wired into `tool/verify.sh` or CI when the queue is non-empty. This fits with the Engineer's existing follow-up (a CI check that every `*.patch` is listed).
4. **(Nit)** `checkout` loops `for p in $(queue_files …)`, which word-splits. It would break if the repo path contained spaces. It is harmless here.

## Notes for the Tech Lead
- Issue 1 is a small fix plus one test. Re-verifying AC3 and AC4 only should be enough afterwards.
- I didn't touch `/Users/emililiev/orca/workspaces/mini-client/tang`. My fork dir and `.bazelrc.user` are deleted, and the Bazel server for my output base is shut down.
