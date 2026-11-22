# ADR-0004: Git integration workflow

- **Status:** Accepted
- **Date:** 2026-11-22
- **Deciders:** Tech Lead. The PO set hosting to GitHub, and on 2026-11-22 explicitly delegated merging to the TL (Q-005).
- **Related:** ADR-0003, T-0006, F-0002, Q-005

## Context
The repo now has a GitHub `origin` (private, HTTPS, no `gh` login, so no PRs from the CLI). The PO explicitly delegated merging to the TL ("I trust you and your decisions; you can merge PRs", Q-005). Crew work in separate worktrees of the same local repo. `main` is checked out in the PO's main checkout (`/Users/emililiev/projects/flutter/mini-client`), so git won't let another worktree check it out.

## Options considered
1. **PRs on GitHub, merged by the PO.** Rejected for now: it puts the PO in the loop for every task and needs `gh` auth for automation.
2. **The TL merges locally and pushes to `origin/main`.** Chosen.
3. **Crew push their own branches.** Rejected: it spreads outward-facing actions across agents.

## Decision
- **`origin/main` is the integration branch and the source of truth.** No force-pushes to it, ever.
- **The TL's worktree branch mirrors `origin/main`** (it tracks `origin/main`). Before integrating: `git fetch origin && git merge --ff-only origin/main`.
- **Crew** branch `fleet/T-XXXX-<slug>` from `origin/main` in their own worktree and commit there. They **never push**. The TL sees their branches directly, because worktrees share one repository.
- **Integration:** after review and the DoD check, the TL runs `git merge --no-ff fleet/T-XXXX-<slug>` (one merge commit per task, for traceability), runs the quality gates, then `GIT_TERMINAL_PROMPT=0 git push origin HEAD:main`. The task branch is then deleted locally and on `origin` if it was pushed.
- **TL bookkeeping commits** (STATUS, BOARD, journal, indexes) go straight onto the TL branch and are pushed to `main`. They are docs-only and owned by the TL (ADR-0003).
- The PO's own checkout of `main` isn't updated automatically. Run `git pull` there to see the latest. The TL doesn't modify that checkout.

## Consequences
- **Positive:** a fully autonomous flow; every task shows up as a single `--no-ff` merge commit on `main`; nothing outward-facing happens without the TL.
- **Negative:** no GitHub-side review record. To get one, the PO runs `gh auth login` and a superseding ADR switches integration to PRs that the TL opens and merges itself (already authorised, Q-005).
- **Follow-up:** once CI exists (T-0005), the TL waits for green CI on `main` after each push and fixes forward if it goes red.
