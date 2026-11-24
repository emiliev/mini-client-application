# Verification report — T-0027: retrofit codegen shim on the rules_dart fork

- **Verifier:** crew: Verifier (fresh agent, not the implementer)
- **Date:** 2026-11-24
- **Branch / commit verified:** `fleet/T-0027-retrofit-shim` @ `eee1877` (detached; the branch is held by the Engineer's worktree)
- **Bazel output base:** `/tmp/mc-ob-T-0027-verifier`
- **Verdict:** WIP (in progress)

## Status
Work in progress. Docs, task file, findings, engineer evidence, patch and check scripts read. AC3 gates running.

## Preliminary observations (to be confirmed)
1. `tool/build_runner_overlay/spike_reference.sh` step 1 still ends its Bazel build with `|| true` (P-024, due "before P3-03 shims"); the AC1 check reuses it. To be demonstrated.
2. `documents/evidence/T-0027/engineer/f0025-bare-freezed-diff.log` holds an injectable (`//spike/di_sample`, T-0028 worktree) build log, not the bare-`@freezed` diff F-0025 cites.
